









#ifndef _PLATFORM_H_
#define _PLATFORM_H_
#pragma once

#include <stdint.h>
#include <string.h>




#define VL53L5CX_NB_TARGET_PER_ZONE		1U




#define VL53L5CX_DISABLE_AMBIENT_PER_SPAD
#define VL53L5CX_DISABLE_NB_SPADS_ENABLED
#define VL53L5CX_DISABLE_NB_TARGET_DETECTED
#define VL53L5CX_DISABLE_SIGNAL_PER_SPAD
#define VL53L5CX_DISABLE_RANGE_SIGMA_MM

#define VL53L5CX_DISABLE_REFLECTANCE_PERCENT

#define VL53L5CX_DISABLE_MOTION_INDICATOR









typedef struct
{
	uint16_t	address;
	uint8_t		ch;
	uint8_t		use_mux;
} VL53L5CX_Platform;






int  vl53l5cx_i2c_init(uint32_t sclk_hz);


int  vl53l5cx_i2c_set_speed(uint32_t sclk_hz);


int  tca9548a_select(uint8_t mask);


void vl53l5cx_i2c_scan(void);



uint8_t VL53L5CX_RdByte(
		VL53L5CX_Platform *p_platform,
		uint16_t RegisterAdress,
		uint8_t *p_value);

uint8_t VL53L5CX_WrByte(
		VL53L5CX_Platform *p_platform,
		uint16_t RegisterAdress,
		uint8_t value);

uint8_t VL53L5CX_RdMulti(
		VL53L5CX_Platform *p_platform,
		uint16_t RegisterAdress,
		uint8_t *p_values,
		uint32_t size);

uint8_t VL53L5CX_WrMulti(
		VL53L5CX_Platform *p_platform,
		uint16_t RegisterAdress,
		uint8_t *p_values,
		uint32_t size);

void VL53L5CX_SwapBuffer(
		uint8_t 		*buffer,
		uint16_t 	 	 size);

uint8_t VL53L5CX_WaitMs(
		VL53L5CX_Platform *p_platform,
		uint32_t TimeMs);

uint8_t VL53L5CX_Reset_Sensor(
		VL53L5CX_Platform *p_platform);

#endif
