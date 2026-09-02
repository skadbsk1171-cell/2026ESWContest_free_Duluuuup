# 2026 임베디드 소프트웨어 경진대회 — 자유공모 | 팀 Duluuuup

## 개요

제조 현장의 비정형 작업(청소·수리·정비·이물질 제거) 중 발생하는 끼임 사고를
막기 위한 안전 제어 시스템입니다. ToF LiDAR로 작업자와 설비 사이의 거리를
실시간으로 측정하고, 거리에 따라 설비를 4단계로 감속·정지시킵니다.

핵심은 **안전 판정을 CPU에서 분리해 FPGA 하드웨어 로직에 구현**한 점입니다.
CPU가 센서 응답 대기로 블로킹되거나 소프트웨어가 정지해도, PL의 안전 회로는
매 클럭마다 독립적으로 감시하며 다음 클럭 상승 엣지에 정지를 실행합니다.

## 문제 정의

- 제조업 끼임 사망사고의 약 54%가 비정형 작업 중 발생
- 안전 덮개·인터록은 비정형 작업 시 해제되고, 라이트커튼은 침입/비침입 2단계 판정에 그침
- 순차 처리 구조의 CPU는 센서 타임아웃(1초) 동안 비상정지 입력을 확인할 수 없음

## 제어 단계

| Zone | 거리 | 위험도 | 설비 속도 |
|---|---|---|---|
| SAFE | 800 mm 초과 | 0단계 | 100% |
| WARNING | 150 ~ 500 mm | 2단계 | 50% |
| DANGER | 150 mm 이하 | 3단계 | 0% (정지) |

## Fail-Safe 설계

센서 오류, 소프트웨어 정지, 비정상 신호 중 하나라도 발생하면 안전 정지합니다.

| 조건 | 감시 모듈 | 신호 |
|---|---|---|
| 센서 오류 | zone_classifier.v | zone_valid 무효화 |
| 소프트웨어 정지 | watchdog.v | heartbeat 미갱신 시 wdt_trip |
| 비동기 입력 | estop_sync.v | 3단 FF 동기화 후 estop_trip |

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_vivado` | 블록 디자인, PL 합성·구현 프로젝트 |
| `02_vitis` | PS 소프트웨어 (센서 드라이버, 거리 측정) |
| `03_verilog` | PL 안전 로직 RTL 소스 및 테스트벤치 |
| `04_python` | 로봇 팔 제어 스크립트 (Raspberry Pi 5) |

## PL 모듈

| 파일 | 기능 |
|---|---|
| `top_safety.v` | 하드웨어 안전 모듈 통합 |
| `safety_fsm.v` | RUNNING / STOPPED 상태 관리 |
| `zone_classifier.v` | 8×8 존 거리를 임계값과 비교해 위험 등급 판정 |
| `risk_reducer.v` | 64개 존 병렬 처리 후 최고 위험도 탐색 |
| `watchdog.v` | heartbeat 미갱신 시 강제 정지 |
| `estop_sync.v` | 비상정지 비동기 신호를 클럭에 동기화 |
| `pwm_gen.v` | 25 kHz PWM 생성, 팬 속도 조절 |
| `brake_ctrl.v` | 1회성 브레이크 펄스 인가 및 과열 하드 리미트 |

## 개발 환경

| 항목 | 버전 |
|---|---|
| Vivado | 2023.x |
| Vitis | 2023.x |
| 타깃 보드 | Digilent Zybo (Zynq-7000) |
| 클럭 | 100 MHz |

## 하드웨어

Digilent Zynq Zybo · Raspberry Pi 5 · VL53L5CX ToF 센서 ·
TCA9548A I²C Multiplexer · PCA9685 PWM Driver · G5LE-14-DC12 Relay ·
IRLZ44N MOSFET · JF-0530B Solenoid · FR120U PWM Fan · 25 kg Servo Motor
