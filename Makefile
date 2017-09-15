# Usage:
#   make all   
BASTION_PID := $(shell pgrep -f bastion_tunnel)

all: build test run

# deploy kubernetes on AWS with a single master and minion
build: 
	@echo 'building kubernetes cluster...'
	terraform apply

test:
	@echo -n "waiting on api to become available..."
	@until [ $$(ssh -q -t -A -l ubuntu `terraform output bastion_public_ip` 'curl -s -I -o /dev/null -w '%{http_code}' http://10.5.5.10:8080') == 200 ]; do echo -n .;sleep 3; done
	@echo done.

run:
	@echo "setting up kubernetes dashboard proxy"
ifeq ($(strip $(BASTION_PID)),)
	exec -a bastion_tunnel ssh -t -A -l ubuntu `terraform output bastion_public_ip` 'ssh -oStrictHostKeyChecking=no -nNT -L `hostname -i`:8080:127.0.0.1:8080 core@10.5.5.10' 1> /dev/null &
	@echo "dashboard proxy pid: ${BASTION_PID}"
else
	@echo "dashboard proxy pid: ${BASTION_PID}"

endif
	kubectl config set-cluster localhost --server=http://`terraform output bastion_public_ip`:8080
	kubectl config set-context localhost --cluster localhost
	kubectl config use-context localhost
	kubectl cluster-info

# tear down entire build and make clean
clean:
	@echo 'deleting this deployment...'
	kubectl config delete-cluster localhost
	terraform destroy -force
	kill -9 $(BASTION_PID) 
