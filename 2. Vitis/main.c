













#include <stdio.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"
#include "sleep.h"
#include "platform.h"
#include "vl53l5cx_api.h"


#define TEST_STAGE      1

#define USE_MUX         0
#define SENSOR1_CH      0
#define SENSOR2_CH      1
#define USE_TWO_SENSORS 0

#define I2C_SPEED_INIT   100000
#define I2C_SPEED_RUN    400000






#define AUTO_RESET      0


#define SAFETY_BASE     XPAR_SAFETY_ZYBO_LEGACY_A_0_S00_AXI_BASEADDR
#define REG_CTRL        0x00
#define REG_DIST1       0x04
#define REG_DIST2       0x08
#define REG_BRAKE_CFG   0x0C
#define REG_STATUS      0x14

#define CTRL_ENABLE     (1u << 0)
#define CTRL_RESET_BTN  (1u << 1)
#define CTRL_HEARTBEAT  (1u << 8)

#define ST_STOPPED(s)     ( (s)        & 1)
#define ST_RELAY(s)       (((s) >> 1)  & 1)
#define ST_FANLEVEL(s)    (((s) >> 2)  & 3)
#define ST_ZONE(s)        (((s) >> 4)  & 3)
#define ST_ESTOP(s)       (((s) >> 6)  & 1)
#define ST_WDT(s)         (((s) >> 7)  & 1)
#define ST_BRAKE(s)       (((s) >> 8)  & 1)
#define ST_BRAKEFAULT(s)  (((s) >> 9)  & 1)



#define DIST_NO_TARGET  4000


static VL53L5CX_Configuration Dev1;
static VL53L5CX_ResultsData   Results;

#if USE_TWO_SENSORS
static VL53L5CX_Configuration Dev2;
#endif

#if TEST_STAGE >= 5
static u32 g_hb = 0;
#endif




static uint16_t nearest_mm(VL53L5CX_ResultsData *res)
{
    uint16_t best = 0xFFFF;
    int i, idx;
    uint8_t  st;
    int16_t  d;

    for (i = 0; i < 64; i++) {
        idx = VL53L5CX_NB_TARGET_PER_ZONE * i;
        st  = res->target_status[idx];



        if (st == 5 || st == 9) {
            d = res->distance_mm[idx];
            if (d > 0 && (uint16_t)d < best) best = (uint16_t)d;
        }
    }
    return best;
}

#if TEST_STAGE == 4

static void print_8x8(VL53L5CX_ResultsData *res)
{
    int r, c, idx, d;

    for (r = 0; r < 8; r++) {
        for (c = 0; c < 8; c++) {
            idx = VL53L5CX_NB_TARGET_PER_ZONE * (r * 8 + c);
            if (res->target_status[idx] == 5 || res->target_status[idx] == 9) {
                d = (int)res->distance_mm[idx];
                if      (d < 10)   xil_printf("   %d ", d);
                else if (d < 100)  xil_printf("  %d ",  d);
                else if (d < 1000) xil_printf(" %d ",   d);
                else               xil_printf("%d ",    d);
            } else {
                xil_printf("   . ");
            }
        }
        xil_printf("\r\n");
    }
    xil_printf("\r\n");
}
#endif

#if TEST_STAGE >= 5

static void kick(void)
{
    g_hb ^= CTRL_HEARTBEAT;
    Xil_Out32(SAFETY_BASE + REG_CTRL, CTRL_ENABLE | g_hb);
}


static void reset_pulse(void)
{
    Xil_Out32(SAFETY_BASE + REG_CTRL, CTRL_ENABLE | g_hb | CTRL_RESET_BTN);
    usleep(2000);
    Xil_Out32(SAFETY_BASE + REG_CTRL, CTRL_ENABLE | g_hb);
    usleep(2000);
}
#endif


static int sensor_bringup(VL53L5CX_Configuration *dev, uint8_t ch, const char *name)
{
    uint8_t status, alive;

    dev->platform.address = VL53L5CX_DEFAULT_I2C_ADDRESS;
    dev->platform.use_mux = USE_MUX;
    dev->platform.ch      = ch;

    xil_printf("\r\n--- %s bring-up ---\r\n", name);

    status = vl53l5cx_is_alive(dev, &alive);
    if (status || !alive) {
        xil_printf("[FAIL] not alive (status=%d alive=%d)\r\n", status, alive);
        return -1;
    }
    xil_printf("[OK] alive\r\n");

#if TEST_STAGE >= 3
    xil_printf("[..] init: uploading 84KB firmware.\r\n");
    xil_printf("[..] takes 8-10s at 100kHz. NO output during this. please wait.\r\n");
    status = vl53l5cx_init(dev);
    if (status) { xil_printf("[FAIL] init status=%d\r\n", status); return -1; }
    xil_printf("[OK] init done (ULD %s)\r\n", VL53L5CX_API_REVISION);
#endif

#if TEST_STAGE >= 4

    status = vl53l5cx_set_resolution(dev, VL53L5CX_RESOLUTION_8X8);
    if (status) { xil_printf("[FAIL] set_resolution=%d\r\n", status); return -1; }
    xil_printf("[OK] resolution 8x8\r\n");


    status = vl53l5cx_set_ranging_frequency_hz(dev, 15);
    if (status) { xil_printf("[FAIL] set_freq=%d\r\n", status); return -1; }

    status = vl53l5cx_set_ranging_mode(dev, VL53L5CX_RANGING_MODE_CONTINUOUS);
    if (status) { xil_printf("[FAIL] set_mode=%d\r\n", status); return -1; }

    status = vl53l5cx_start_ranging(dev);
    if (status) { xil_printf("[FAIL] start_ranging=%d\r\n", status); return -1; }
    xil_printf("[OK] ranging started\r\n");
#endif
    return 0;
}



int main(void)
{
    uint8_t  isReady, status;
    uint16_t d1;
#if USE_TWO_SENSORS
    uint16_t d2;
#endif
#if TEST_STAGE >= 5
    uint32_t s;
    int      safe_ticks = 0;
#endif

    xil_printf("\r\n\r\n===== VL53L5CX bring-up  STAGE %d =====\r\n", TEST_STAGE);

    if (vl53l5cx_i2c_init(I2C_SPEED_INIT) != 0) {
        xil_printf("I2C init failed. halt.\r\n");
        while (1) { }
    }

#if TEST_STAGE == 1
    vl53l5cx_i2c_scan();
    xil_printf("expect: 0x29 (sensor), 0x70 (TCA9548A)\r\n");
    xil_printf("0 device(s) with nothing connected is normal.\r\n");
    while (1) { }
#else

#if USE_MUX
    tca9548a_select(1u << SENSOR1_CH);
#endif

    if (sensor_bringup(&Dev1, SENSOR1_CH, "SENSOR1") != 0) while (1) { }

#if USE_TWO_SENSORS
    if (sensor_bringup(&Dev2, SENSOR2_CH, "SENSOR2") != 0) while (1) { }
#endif

#if TEST_STAGE < 4
    xil_printf("\r\nSTAGE %d passed. raise TEST_STAGE and rebuild.\r\n", TEST_STAGE);
    while (1) { }
#else

    vl53l5cx_i2c_set_speed(I2C_SPEED_RUN);

#if TEST_STAGE >= 5

    Xil_Out32(SAFETY_BASE + REG_CTRL, CTRL_ENABLE);
    Xil_Out32(SAFETY_BASE + REG_BRAKE_CFG, 0);




    Xil_Out32(SAFETY_BASE + REG_DIST1, DIST_NO_TARGET);
    Xil_Out32(SAFETY_BASE + REG_DIST2, DIST_NO_TARGET);
    kick();
    usleep(50000);


    reset_pulse();
    usleep(50000);

    s = Xil_In32(SAFETY_BASE + REG_STATUS);
    if (ST_STOPPED(s)) {
        xil_printf("[WARN] still STOPPED after reset. "
                   "check E-stop wiring and heartbeat.\r\n");
    } else {
        xil_printf("[OK] safety core RUNNING\r\n");
    }
#endif

    xil_printf("\r\n===== ranging loop =====\r\n");
    while (1) {
        d1 = 0xFFFF;
#if USE_TWO_SENSORS
        d2 = 0xFFFF;
#endif
        status = vl53l5cx_check_data_ready(&Dev1, &isReady);
        if (!status && isReady) {
            if (vl53l5cx_get_ranging_data(&Dev1, &Results) == 0) {
                d1 = nearest_mm(&Results);
#if TEST_STAGE == 4
                print_8x8(&Results);
#endif
            }
        }

#if USE_TWO_SENSORS
        status = vl53l5cx_check_data_ready(&Dev2, &isReady);
        if (!status && isReady) {
            if (vl53l5cx_get_ranging_data(&Dev2, &Results) == 0)
                d2 = nearest_mm(&Results);
        }
#endif

#if TEST_STAGE >= 5


        Xil_Out32(SAFETY_BASE + REG_DIST1,
                  (d1 == 0xFFFF) ? DIST_NO_TARGET : d1);
#if USE_TWO_SENSORS
        Xil_Out32(SAFETY_BASE + REG_DIST2,
                  (d2 == 0xFFFF) ? DIST_NO_TARGET : d2);
#else
        Xil_Out32(SAFETY_BASE + REG_DIST2, DIST_NO_TARGET);
#endif
        kick();

        s = Xil_In32(SAFETY_BASE + REG_STATUS);
        xil_printf("d1=%d | stop=%d relay=%d fan=%d zone=%d "
                   "estop=%d wdt=%d brake=%d fault=%d\r\n",
                   (d1 == 0xFFFF) ? DIST_NO_TARGET : d1,
                   ST_STOPPED(s), ST_RELAY(s), ST_FANLEVEL(s), ST_ZONE(s),
                   ST_ESTOP(s), ST_WDT(s), ST_BRAKE(s), ST_BRAKEFAULT(s));

#if AUTO_RESET


        if (ST_STOPPED(s) && ST_ZONE(s) == 0 && !ST_ESTOP(s) && !ST_WDT(s)) {
            if (++safe_ticks > 40) {
                xil_printf("[auto-reset]\r\n");
                reset_pulse();
                safe_ticks = 0;
            }
        } else {
            safe_ticks = 0;
        }
#else
        (void)safe_ticks;
#endif

#else
        xil_printf("nearest = %d mm\r\n",
                   (d1 == 0xFFFF) ? DIST_NO_TARGET : d1);
#endif
        usleep(50 * 1000);
    }
#endif
#endif

    return 0;
}
