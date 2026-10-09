# STM32 Environmental Monitoring & Alert System

An embedded firmware prototype developed using the STM32 Nucleo-C031C6 board in Wokwi.

## Project Overview

This project monitors an analog input, classifies the system condition, and activates appropriate status indicators and alerts.

A potentiometer simulates the sensor signal during testing.

## Technologies Used

- STM32 Nucleo-C031C6
- Embedded C/C++ and STM32 Arduino framework
- Wokwi simulation
- ADC and GPIO
- Hardware timer and interrupt
- UART serial communication
- SPI communication
- LED and buzzer alerts

## Key Features

- Periodic ADC sampling
- Eight-sample averaging
- NORMAL, WARNING, ALERT and FAULT states
- Hysteresis-based state transitions
- Sensor fault detection and recovery
- UART diagnostics
- LED and buzzer alerts
- SPI shift-register status indication

## ADC Thresholds

- ADC <= 10: FAULT
- NORMAL to WARNING: ADC >= 465
- WARNING to NORMAL: ADC < 434
- WARNING to ALERT: ADC > 775
- ALERT to WARNING: ADC < 744

## Pin Mapping

- PA0: Analog input
- PC7: Status LED
- D6: Buzzer
- D10: SPI latch
- D11 / PA7: SPI MOSI
- D13 / PA5: SPI clock
- PA2 / PA3: UART connections

## Testing

Tested in Wokwi with simulated analog input changes, including threshold transitions, hysteresis, rapid changes, fault detection and recovery.

## Simulation

https://wokwi.com/projects/475522633689443329

## Limitations

The potentiometer simulates an analog sensor signal. DHT22 and OLED integration are not yet verified in the complete application.

## Future Improvements

- Validate integration with an environmental sensor
- Improve firmware modularity
- Expand automated testing
- Explore an RTOS-based implementation
