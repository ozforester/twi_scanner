# Copyright (c) 2021 ozforester. All rights reserved.
# Use of this source code is goverened by a MIT license
# that can be found in the LICENSE file.


TARGET	 = leds_twi
SOURCES := $(wildcard *.S)
OBJECTS  = $(SOURCES:.S=.o)
HEX = $(SOURCES:.S=.hex)
F_CPU = 4000000L

all:
	avr-gcc -DF_CPU=${F_CPU} -Wall -Os -mmcu=atmega8 -o ${TARGET}.o ${TARGET}.S
	avr-ld -o ${TARGET}.elf ${TARGET}.o
	avr-objcopy -O ihex ${TARGET}.elf ${TARGET}.hex
	avr-size ${TARGET}.elf
	avr-size ${TARGET}.hex

flash:
	avrdude -c usbasp -p m8 -B 2 -U flash:w:${TARGET}.hex

clean:
	rm -f $(OBJECTS) $(TARGET).o $(TARGET).elf $(TARGET).hex
