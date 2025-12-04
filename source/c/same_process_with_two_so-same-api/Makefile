CC = gcc
CFLAGS = -fPIC
LDFLAGS = -shared
RPATH = -Wl,-rpath=.
INCLUDE = -I.
SONAME = -Wl,-soname,

TARGET1 = test1
TARGET2 = test2
TARGET_AUTO = test_auto

LIBS = libc1.so libc2.so liba.so libb.so

all: $(LIBS) $(TARGET1) $(TARGET2) $(TARGET_AUTO)

# 编译 libc1.so
libc1.so: libc1.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDE) $(SONAME)libc1.so -o $@ $<

# 编译 libc2.so
libc2.so: libc2.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDE) $(SONAME)libc2.so -o $@ $<

# 编译 liba.so，依赖 libc1.so
liba.so: liba.c libc1.so
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDE) -o $@ liba.c -L. -lc1 $(RPATH)

# 编译 libb.so，依赖 libc2.so
libb.so: libb.c libc2.so
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDE) -o $@ libb.c -L. -lc2 $(RPATH)

$(TARGET1): test1.c liba.so libb.so
	$(CC) test1.c -ldl -L. $(RPATH) -o $@

$(TARGET2): test2.c liba.so libb.so
	$(CC) test2.c -ldl -L. $(RPATH) -o $@

$(TARGET_AUTO): test_auto.c liba.so libb.so
	$(CC) test_auto.c -L. -la -lb $(RPATH) -o $@

# 运行测试
run1: $(TARGET1)
	LD_LIBRARY_PATH=. ./$(TARGET1)

run2: $(TARGET2)
	LD_LIBRARY_PATH=. ./$(TARGET2)

run_auto: $(TARGET_AUTO)
	readelf -d liba.so | grep -i needed
	readelf -d libb.so | grep -i needed
	LD_LIBRARY_PATH=. ./$(TARGET_AUTO)

# 清理
clean:
	rm -f $(TARGET1) $(TARGET2) $(TARGET_AUTO) $(LIBS)

