
create:
	$(MAKE) -f eks.Makefile binaries $@ kubeconfig
	$(MAKE) -f workers.Makefile $@ node_type=t2.small
	$(MAKE) -f workers.Makefile $@ node_type=t2.medium

delete:
	$(MAKE) -f workers.Makefile $@ node_type=t2.medium
	$(MAKE) -f workers.Makefile $@ node_type=t2.small
	$(MAKE) -f eks.Makefile $@
	$(MAKE) -f eks.Makefile clean
