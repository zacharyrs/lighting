SRCDIR = ./src/
INCDIR = ./include/
GENDIR = ./gen/

OBJDIR := $(GENDIR)obj/
DEPDIR := $(GENDIR)dep/

CROSS_PREFIX := arm-none-eabi
CC := $(CROSS_PREFIX)-gcc
LD := $(CROSS_PREFIX)-gcc
OBJCOPY := $(CROSS_PREFIX)-objcopy

CFLAGS := -Os -std=gnu18 -g3 \
	-Wextra -Wshadow -Wimplicit-function-declaration \
	-Wredundant-decls -Wmissing-prototypes -Wstrict-prototypes \
	-fno-common -ffunction-sections -fdata-sections \
	-mcpu=cortex-m3 -mthumb -mfix-cortex-m3-ldrd \
	-DSTM32F1

DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)$*.Td

LDFlAGS := --static -T./bluepill.ld -nostartfiles \
	-mcpu=cortex-m3 -mthumb -mfix-cortex-m3-ldrd \
	-Wl,--gc-sections

OPENCM3DIR = ./deps/libopencm3/
RTOSDIR = ./deps/FreeRTOS/FreeRTOS/Source/
RTOSSRC = list.c queue.c tasks.c portable/MemMang/heap_4.c portable/GCC/ARM_CM3/port.c

INCLUDES := \
	-I$(OPENCM3DIR)include \
	-I$(INCDIR) \
	-I$(INCDIR)rtos/

LIBRARIES := \
	-L$(OPENCM3DIR)lib

LDLIBs := -specs=nosys.specs \
	-Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group \
	-lopencm3_stm32f1

SOURCES = $(wildcard $(SRCDIR)*.c) $(addprefix $(SRCDIR)rtos/,$(notdir $(RTOSSRC)))
OBJECTS = $(patsubst $(SRCDIR)%.c,$(OBJDIR)%.o,$(SOURCES))
EXECUTABLE = lighting

all: deps dir $(EXECUTABLE).bin $(EXECUTABLE).hex

deps: libopencm3 freertos

libopencm3:
	if [ ! -f $(OPENCM3DIR)Makefile ]; then \
		echo "Initialising git submodules..." ;\
		git submodule init;\
		git submodule update;\
	fi
	$(MAKE) -C $(OPENCM3DIR) TARGETS=stm32/f1

freertos:
	if [ ! -f $(RTOSDIR)README.md ]; then \
		echo "Initialising git submodules..." ;\
		git submodule init --recursive;\
		git submodule update --recursive;\
	fi
	mkdir -p $(SRCDIR)rtos/
	mkdir -p $(INCDIR)rtos/
	cp $(RTOSDIR)include/*.h $(INCDIR)rtos/
	cp $(RTOSDIR)portable/GCC/ARM_CM3/*.h $(INCDIR)rtos/
	@for f in $(RTOSSRC); do \
		cp $(RTOSDIR)$$f $(SRCDIR)rtos/; \
	done

dir:
	mkdir -p $(GENDIR)

clean:
	rm -rf $(GENDIR)
	rm $(EXECUTABLE).*
	$(MAKE) -C deps/libopencm3 clean

$(OBJDIR)%.o: $(SRCDIR)%.c
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $(DEPDIR)$*)
	$(CC) $(CFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
	@mv -f $(DEPDIR)$*.Td $(DEPDIR)$*.d

$(EXECUTABLE).elf: $(OBJECTS)
	$(LD) $(LDFlAGS) $(LIBRARIES) $^ $(LDLIBs) -o $@

$(EXECUTABLE).bin: $(EXECUTABLE).elf
	$(OBJCOPY) -Obinary $^ $@

$(EXECUTABLE).hex: $(EXECUTABLE).elf
	$(OBJCOPY) -Oihex $^ $@

-include $(patsubst $(OBJDIR)%.o,$(DEPDIR)%.d,$(OBJECTS))