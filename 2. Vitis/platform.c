


















#include "platform.h"

#include "xparameters.h"
#include "xiicps.h"
#include "xstatus.h"
#include "sleep.h"
#include <stdio.h>





#ifndef VL53_IIC_DEVICE_ID
  #ifdef XPAR_XIICPS_0_DEVICE_ID
    #define VL53_IIC_DEVICE_ID   XPAR_XIICPS_0_DEVICE_ID
  #else
    #define VL53_IIC_DEVICE_ID   XPAR_PS7_I2C_1_DEVICE_ID
  #endif
#endif


#define TCA9548A_ADDR7      0x70




#define WR_CHUNK            256u
#define RD_CHUNK            128u



#define USE_REPEATED_START  1



static XIicPs   IicPs;
static int      g_iic_ready = 0;
static uint8_t  g_cur_mux   = 0xFF;
static uint8_t  s_txbuf[WR_CHUNK + 2];



static int iic_raw_send(uint16_t addr7, uint8_t *buf, uint32_t len)
{
    if (XIicPs_MasterSendPolled(&IicPs, buf, (s32)len, addr7) != XST_SUCCESS)
        return -1;
    while (XIicPs_BusIsBusy(&IicPs)) {  }
    return 0;
}


int tca9548a_select(uint8_t mask)
{
    uint8_t b = mask;
    if (!g_iic_ready) return -1;
    if (g_cur_mux == mask) return 0;
    if (iic_raw_send(TCA9548A_ADDR7, &b, 1) != 0) return -1;
    g_cur_mux = mask;
    return 0;
}

static int mux_apply(VL53L5CX_Platform *p)
{
    if (p && p->use_mux)
        return tca9548a_select((uint8_t)(1u << p->ch));
    return 0;
}


static int reg_write(uint16_t addr7, uint16_t reg, const uint8_t *data, uint32_t size)
{
    uint32_t sent = 0;


    while (sent < size) {
        uint32_t n = size - sent;
        uint32_t r;
        if (n > WR_CHUNK) n = WR_CHUNK;

        r = (uint32_t)reg + sent;
        s_txbuf[0] = (uint8_t)((r >> 8) & 0xFF);
        s_txbuf[1] = (uint8_t)( r       & 0xFF);
        memcpy(&s_txbuf[2], data + sent, n);

        if (iic_raw_send(addr7, s_txbuf, n + 2) != 0)
            return -1;

        sent += n;
    }
    return 0;
}


static int reg_read(uint16_t addr7, uint16_t reg, uint8_t *data, uint32_t size)
{
    uint32_t got = 0;

    while (got < size) {
        uint32_t n = size - got;
        uint32_t r;
        uint8_t  ra[2];
        if (n > RD_CHUNK) n = RD_CHUNK;

        r = (uint32_t)reg + got;
        ra[0] = (uint8_t)((r >> 8) & 0xFF);
        ra[1] = (uint8_t)( r       & 0xFF);

#if USE_REPEATED_START
        XIicPs_SetOptions(&IicPs, XIICPS_REP_START_OPTION);
        if (XIicPs_MasterSendPolled(&IicPs, ra, 2, addr7) != XST_SUCCESS) {
            XIicPs_ClearOptions(&IicPs, XIICPS_REP_START_OPTION);
            return -1;
        }
        XIicPs_ClearOptions(&IicPs, XIICPS_REP_START_OPTION);
#else
        if (iic_raw_send(addr7, ra, 2) != 0) return -1;
#endif
        if (XIicPs_MasterRecvPolled(&IicPs, data + got, (s32)n, addr7) != XST_SUCCESS)
            return -1;
        while (XIicPs_BusIsBusy(&IicPs)) {  }

        got += n;
    }
    return 0;
}



int vl53l5cx_i2c_init(uint32_t sclk_hz)
{
    XIicPs_Config *cfg;
    int st;

    cfg = XIicPs_LookupConfig(VL53_IIC_DEVICE_ID);
    if (cfg == NULL) {
        xil_printf("[I2C] LookupConfig FAIL (device id %d)\r\n", VL53_IIC_DEVICE_ID);
        return -1;
    }

    st = XIicPs_CfgInitialize(&IicPs, cfg, cfg->BaseAddress);
    if (st != XST_SUCCESS) {
        xil_printf("[I2C] CfgInitialize FAIL (%d)\r\n", st);
        return -1;
    }


    st = XIicPs_SelfTest(&IicPs);
    if (st != XST_SUCCESS) {
        xil_printf("[I2C] SelfTest FAIL (%d)\r\n", st);
        return -1;
    }

    if (XIicPs_SetSClk(&IicPs, sclk_hz) != XST_SUCCESS) {
        xil_printf("[I2C] SetSClk FAIL\r\n");
        return -1;
    }

    g_iic_ready = 1;
    g_cur_mux   = 0xFF;
    xil_printf("[I2C] init OK  base=0x%08X  sclk=%d Hz\r\n",
               (unsigned)cfg->BaseAddress, (int)sclk_hz);
    return 0;
}

int vl53l5cx_i2c_set_speed(uint32_t sclk_hz)
{
    if (!g_iic_ready) return -1;
    if (XIicPs_SetSClk(&IicPs, sclk_hz) != XST_SUCCESS) return -1;
    xil_printf("[I2C] sclk -> %d Hz\r\n", (int)sclk_hz);
    return 0;
}

void vl53l5cx_i2c_scan(void)
{
    uint8_t dummy;
    int a, found = 0;

    if (!g_iic_ready) { xil_printf("[I2C] not initialized\r\n"); return; }

    xil_printf("[I2C] scanning 0x08..0x77 ...\r\n");
    for (a = 0x08; a <= 0x77; a++) {
        if (XIicPs_MasterRecvPolled(&IicPs, &dummy, 1, (u16)a) == XST_SUCCESS) {
            xil_printf("   found 7-bit 0x%02X  (8-bit 0x%02X)\r\n", a, a << 1);
            found++;
        }
        while (XIicPs_BusIsBusy(&IicPs)) { }
        usleep(1000);
    }
    xil_printf("[I2C] scan done, %d device(s)\r\n", found);

}




uint8_t VL53L5CX_RdByte(VL53L5CX_Platform *p_platform,
                        uint16_t RegisterAdress,
                        uint8_t *p_value)
{
    if (mux_apply(p_platform) != 0) return 255;
    if (reg_read((uint16_t)(p_platform->address >> 1), RegisterAdress, p_value, 1) != 0)
        return 255;
    return 0;
}

uint8_t VL53L5CX_WrByte(VL53L5CX_Platform *p_platform,
                        uint16_t RegisterAdress,
                        uint8_t value)
{
    if (mux_apply(p_platform) != 0) return 255;
    if (reg_write((uint16_t)(p_platform->address >> 1), RegisterAdress, &value, 1) != 0)
        return 255;
    return 0;
}

uint8_t VL53L5CX_RdMulti(VL53L5CX_Platform *p_platform,
                         uint16_t RegisterAdress,
                         uint8_t *p_values,
                         uint32_t size)
{
    if (mux_apply(p_platform) != 0) return 255;
    if (reg_read((uint16_t)(p_platform->address >> 1), RegisterAdress, p_values, size) != 0)
        return 255;
    return 0;
}

uint8_t VL53L5CX_WrMulti(VL53L5CX_Platform *p_platform,
                         uint16_t RegisterAdress,
                         uint8_t *p_values,
                         uint32_t size)
{
    if (mux_apply(p_platform) != 0) return 255;
    if (reg_write((uint16_t)(p_platform->address >> 1), RegisterAdress, p_values, size) != 0)
        return 255;
    return 0;
}


void VL53L5CX_SwapBuffer(uint8_t *buffer, uint16_t size)
{
    uint32_t i, tmp;

    for (i = 0; i < (uint32_t)size; i = i + 4) {
        tmp = ((uint32_t)buffer[i]     << 24)
            | ((uint32_t)buffer[i + 1] << 16)
            | ((uint32_t)buffer[i + 2] <<  8)
            | ((uint32_t)buffer[i + 3]);
        memcpy(&(buffer[i]), &tmp, 4);
    }
}

uint8_t VL53L5CX_WaitMs(VL53L5CX_Platform *p_platform, uint32_t TimeMs)
{
    (void)p_platform;
    usleep(TimeMs * 1000u);
    return 0;
}







uint8_t VL53L5CX_Reset_Sensor(VL53L5CX_Platform *p_platform)
{
    (void)p_platform;
    usleep(100 * 1000u);
    return 0;
}
