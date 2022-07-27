bindir=$(DESTDIR)/bin

all: zicross_demo_c
	
%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)
	
zicross_demo_c: main.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(bindir):
	mkdir -p $@

install: zicross_demo_c $(bindir)
	cp -t $(bindir) zicross_demo_c

.PHONY: install