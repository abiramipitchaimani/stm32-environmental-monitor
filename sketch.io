#include <SPI.h>

// ============================================================
// HARDWARE CONFIGURATION
// ============================================================

#define LATCH_PIN   D10
#define SENSOR_PIN  PA0
#define LED_PIN     PC7
#define BUZZER_PIN  D6


// ============================================================
// ADC THRESHOLDS
// ============================================================

// Sensor fault threshold
#define SENSOR_FAULT_THRESHOLD  10

// Normal <-> Warning
#define ADC_NORMAL_TO_WARNING   465
#define ADC_WARNING_TO_NORMAL   434

// Warning <-> Alert
#define ADC_WARNING_TO_ALERT    775
#define ADC_ALERT_TO_WARNING    744


// ============================================================
// TIMER
// ============================================================

HardwareTimer *MyTimer;

volatile bool sensor_due = false;


// ============================================================
// SYSTEM STATES
// ============================================================

enum SystemState
{
    STATE_NORMAL,
    STATE_WARNING,
    STATE_ALERT,
    STATE_FAULT
};

SystemState currentState = STATE_NORMAL;


// ============================================================
// TIMER INTERRUPT
// ============================================================

void timerISR()
{
    // Keep ISR short.
    // Sensor processing is done in loop().
    sensor_due = true;
}


// ============================================================
// ADC SENSOR READING
// ============================================================

int readSensor()
{
    long total = 0;

    // Take 8 ADC readings
    // and calculate their average.

    for (int i = 0; i < 8; i++)
    {
        total += analogRead(SENSOR_PIN);
        delay(2);
    }

    return total / 8;
}


// ============================================================
// STATE MACHINE
// ============================================================

SystemState determineState(int adc)
{
    // --------------------------------------------------------
    // SENSOR FAULT
    // --------------------------------------------------------

    if (adc <= SENSOR_FAULT_THRESHOLD)
    {
        return STATE_FAULT;
    }


    // --------------------------------------------------------
    // CURRENT STATE: NORMAL
    // --------------------------------------------------------

    if (currentState == STATE_NORMAL)
    {
        // Direct NORMAL -> ALERT
        if (adc > ADC_WARNING_TO_ALERT)
        {
            return STATE_ALERT;
        }

        // NORMAL -> WARNING
        if (adc >= ADC_NORMAL_TO_WARNING)
        {
            return STATE_WARNING;
        }

        return STATE_NORMAL;
    }


    // --------------------------------------------------------
    // CURRENT STATE: WARNING
    // --------------------------------------------------------

    if (currentState == STATE_WARNING)
    {
        // WARNING -> NORMAL
        if (adc < ADC_WARNING_TO_NORMAL)
        {
            return STATE_NORMAL;
        }

        // WARNING -> ALERT
        if (adc > ADC_WARNING_TO_ALERT)
        {
            return STATE_ALERT;
        }

        return STATE_WARNING;
    }


    // --------------------------------------------------------
    // CURRENT STATE: ALERT
    // --------------------------------------------------------

    if (currentState == STATE_ALERT)
    {
        // ALERT -> WARNING
        if (adc < ADC_ALERT_TO_WARNING)
        {
            return STATE_WARNING;
        }

        return STATE_ALERT;
    }


    // --------------------------------------------------------
    // CURRENT STATE: FAULT
    // --------------------------------------------------------

    if (currentState == STATE_FAULT)
    {
        // Sensor recovered
        if (adc > SENSOR_FAULT_THRESHOLD)
        {
            // Recover into NORMAL
            if (adc < ADC_NORMAL_TO_WARNING)
            {
                return STATE_NORMAL;
            }

            // Recover into WARNING
            if (adc <= ADC_WARNING_TO_ALERT)
            {
                return STATE_WARNING;
            }

            // Recover directly into ALERT
            return STATE_ALERT;
        }

        // Sensor is still faulty
        return STATE_FAULT;
    }


    // Safety fallback
    return STATE_FAULT;
}


// ============================================================
// SPI STATUS OUTPUT
// ============================================================

void updateSPIStatus(SystemState state)
{
    byte data;

    switch (state)
    {
        // QA ON
        case STATE_NORMAL:
            data = 0b11111110;
            break;

        // QB ON
        case STATE_WARNING:
            data = 0b11111101;
            break;

        // QC ON
        case STATE_ALERT:
            data = 0b11111011;
            break;

        // QD ON
        case STATE_FAULT:
            data = 0b11110111;
            break;

        default:
            data = 0xFF;
            break;
    }


    // Send data to 74HC595/NLSF595

    digitalWrite(LATCH_PIN, LOW);

    SPI.transfer(data);

    digitalWrite(LATCH_PIN, HIGH);
}


// ============================================================
// LED + BUZZER + UART OUTPUT
// ============================================================

void applyState(SystemState state)
{
    // Update SPI status indicator
    updateSPIStatus(state);


    switch (state)
    {
        // ----------------------------------------------------
        // NORMAL
        // ----------------------------------------------------

        case STATE_NORMAL:

            digitalWrite(LED_PIN, LOW);

            noTone(BUZZER_PIN);

            Serial.println("NORMAL");

            break;


        // ----------------------------------------------------
        // WARNING
        // ----------------------------------------------------

        case STATE_WARNING:

            digitalWrite(LED_PIN, HIGH);

            noTone(BUZZER_PIN);

            Serial.println("WARNING");

            break;


        // ----------------------------------------------------
        // ALERT
        // ----------------------------------------------------

        case STATE_ALERT:

            digitalWrite(LED_PIN, HIGH);

            tone(BUZZER_PIN, 1000);

            Serial.println("ALERT");

            break;


        // ----------------------------------------------------
        // FAULT
        // ----------------------------------------------------

        case STATE_FAULT:

            digitalWrite(LED_PIN, HIGH);

            tone(BUZZER_PIN, 500);

            Serial.println("FAULT");

            break;
    }
}


// ============================================================
// SENSOR MONITORING
// ============================================================

void monitorSystem()
{
    // Read sensor
    int adc = readSensor();


    // Display ADC value
    Serial.print("ADC=");
    Serial.println(adc);


    // Determine system state
    currentState = determineState(adc);


    // Apply outputs
    applyState(currentState);
}


// ============================================================
// SETUP
// ============================================================

void setup()
{
    // --------------------------------------------------------
    // UART
    // --------------------------------------------------------

    Serial.begin(115200);


    // --------------------------------------------------------
    // GPIO
    // --------------------------------------------------------

    pinMode(LED_PIN, OUTPUT);

    pinMode(BUZZER_PIN, OUTPUT);

    pinMode(LATCH_PIN, OUTPUT);


    // Initial output states

    digitalWrite(LED_PIN, LOW);

    digitalWrite(BUZZER_PIN, LOW);

    digitalWrite(LATCH_PIN, HIGH);


    // --------------------------------------------------------
    // SPI
    // --------------------------------------------------------

    SPI.begin();


    // --------------------------------------------------------
    // HARDWARE TIMER
    // --------------------------------------------------------

#if defined(TIM1)

    TIM_TypeDef *Instance = TIM1;

#else

    TIM_TypeDef *Instance = TIM2;

#endif


    MyTimer = new HardwareTimer(Instance);


    // 10 Hz timer
    //
    // 10 events per second
    // = one event every 100 ms

    MyTimer->setOverflow(10, HERTZ_FORMAT);


    // Attach interrupt

    MyTimer->attachInterrupt(timerISR);


    // Start timer

    MyTimer->resume();


    // --------------------------------------------------------
    // STARTUP
    // --------------------------------------------------------

    Serial.println("START");

    applyState(currentState);
}


// ============================================================
// MAIN APPLICATION LOOP
// ============================================================

void loop()
{
    // Check whether timer generated an event

    if (sensor_due)
    {
        sensor_due = false;


        // Process sensor immediately
        // after every timer event.

        monitorSystem();
    }
}
