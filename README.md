# SoC_SPI_I2C

## 🚀 SoC\_SPI\_I2C: 통신 인터페이스 설계 및 검증 (Communication Interface Design and Verification)

본 프로젝트는 대표적인 동기식 직렬 통신 프로토콜인 **SPI (Serial Peripheral Interface)**와 **I2C (Inter-Integrated Circuit)** 통신 인터페이스를 **SystemVerilog (HDL)**로 설계하고, 이를 실제 하드웨어 제어 애플리케이션에 적용하며 **UVM(Universal Verification Methodology)**을 이용해 검증하는 것을 목표로 합니다.

### 🎯 주요 목표 (Key Goals)

* **Communication Interface:** SPI / I2C 통신 인터페이스 설계.
* **Application:** 하드웨어를 제어할 수 있는 애플리케이션 구현.
* **Verification:** UVM 프레임워크를 이용한 통신 프로토콜 검증.

---

## 🛠️ 1. SPI 통신 프로젝트: Upcounter 구현

SPI 통신 모듈을 설계하고, 이를 이용하여 마스터 보드에서 생성된 카운트 값을 슬레이브 보드의 **7-세그먼트(FND)에 표시**하는 Upcounter 시스템을 구현했습니다.

### SPI 통신 특징

* **구조:** 마스터와 슬레이브로 구성되는 동기식 직렬 통신 프로토콜입니다.
* **신호선:** 4-Wire (SCLK, MOSI, MISO, CS)를 사용하며, 1:N 통신이 가능합니다.
* **통신 방식:** 클럭 신호로 타이밍을 동기화하며, 동시에 데이터 송수신(전이중 통신)이 가능합니다.

### 모듈 구성 (Block Diagram)

| 구분 | 파일명 | 역할 및 주요 기능 |
| :--- | :--- | :--- |
| **Master** | `spi_master.sv` | SPI 통신 마스터 로직 구현 (CPOL=0, CPHA=0 설정). |
| | `upcounter.sv` | `run`, `stop`, `clear` 신호를 받아 **16비트 카운터**를 제어하고, 이 값을 8비트씩 나누어 SPI 마스터로 전송하는 Master Control Unit 역할을 수행합니다. |
| **Slave** | `spi_slave.sv` | SPI 통신 슬레이브 로직 구현. |
| | `control_unit.sv` | 슬레이브로부터 수신된 상위 8비트/하위 8비트를 결합하여 **14비트** 카운트 데이터(`count_data` = `data_reg[13:0]`)를 FND 컨트롤러에 전달합니다. |
| | `fnd_controller.sv` | 14비트 카운트 데이터를 받아 4-Digit FND를 동적 구동합니다. |

---

## 🔬 2. I2C 통신 설계 및 UVM 검증

I2C 통신 프로토콜을 설계하고, **UVM (Universal Verification Methodology)** 환경을 구축하여 설계의 정합성을 검증했습니다.

### I2C 통신 특징

* **개발:** 필립스에서 개발된 동기식 직렬 통신 프로토콜입니다.
* **신호선:** 2-Wire (**SCL**, **SDA**)을 사용하는 반이중 통신입니다.
* **신호:** Open Drain 구조를 사용합니다.
* **프로토콜:** **START 조건** (SDA High→Low, SCL High)으로 통신을 시작하며, 주소(7비트)와 읽기/쓰기 비트를 통해 데이터를 송수신합니다.

### UVM 검증 환경 (`tb_i2c.sv`)

* **목표:** I2C Write 동작 (주소 + 데이터 쓰기)을 검증합니다.
* **구조:** Sequence, Sequencer, Driver, Monitor, Scoreboard 표준 UVM 컴포넌트를 사용하여 구축되었습니다.
    * **Sequencer:** `i2c_seq_item` 트랜잭션을 생성하여 Driver에 전달합니다.
    * **Driver:** 트랜잭션을 DUT(`i2c_master`)의 인터페이스 신호로 변환하여 인가합니다.
    * **Monitor:** DUT 인터페이스의 신호를 다시 트랜잭션으로 변환하여 Scoreboard에 전달합니다.
    * **Scoreboard:** 마스터 송신 데이터(`tr.data`)와 슬레이브 수신 데이터(`tr.s_data`)를 비교하여 DUT 동작의 일치 여부를 검증합니다.

### 검증 결과

* **Total Transactions:** 256
* **Tests Passed:** 256
* **Tests Failed:** 0
* **결론:** 총 256개의 테스트를 수행하여 **모두 성공**했습니다.

---

## 🖥️ 3. C 애플리케이션 및 최종 구현

I2C Master IP를 **AXI Interface**로 구현하고, Microblaze 기반의 SoC 환경에 통합했습니다. C 애플리케이션을 통해 Slave 보드의 주변 장치(LED, FND)를 제어하는 시스템을 구축했습니다.

### 구현 구조 (Microblaze + I2C)

* **Master Board:** Microblaze CPU, AXI4 Lite, I2C Master IP, UART 통신을 포함합니다.
* **Slave Board:** I2C Slave 모듈, LED, FND로 구성됩니다.
* **SW 계층:** C Application(`UART FND LED control`)에서 FND/LED Driver를 통해 I2C 통신으로 Slave 보드의 하드웨어를 제어하는 계층 구조를 가집니다.

---

## 💡 고찰 (Conclusion)

* **통신 프로토콜 이해:** 대표적인 시리얼 통신들을 직접 설계하고 적용해 보면서 기술적 이해도가 향상되었습니다.
* **Debugging의 중요성:** Verdi 파형 분석과 Logic Analyzer를 활용한 디버깅을 통해 문제 해결 능력을 키웠습니다.
