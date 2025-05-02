Initial cmds run on remote host:

```shell
echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/no_pass.conf &&
    sudo mv /etc/ssh/sshd_config.d/{50-cloud-init.conf,.orig} ;
    sudo systemctl reload ssh
```

Ansible prep:
```shell
devenv shell
source .devenv/state/venv/bin/activate
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/<key_name>
ansible-playbook -K -i inventory.yml playbooks/base-playbook.yml
ansible-playbook -i inventory.yml playbooks/hardening-playbook.yml
```