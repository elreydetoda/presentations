{ pkgs, lib, config, inputs, ... }:

{
  cachix.enable = false;
  name = "mycroft";
  # https://devenv.sh/basics/
  # env.GREET = "devenv";
  env = {
    ANSIBLE_PYTHON_INTERPRETER = "python3";
    FULL_SSH_KEY_PATH = "";
  };

  # https://devenv.sh/packages/
  packages = with pkgs; [
    coreutils
    git
    direnv
  ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;
  languages = {
    python = {
      enable = true;
      uv = {
        enable = true;
      };
    };
  };

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts = {
    # https://github.com/elreydetoda/packer-kali_linux/blob/9b55291d17df7f1859bc456272c5797f52d529fc/prov_vagrant/prov.sh#L116
    proj_select.exec = ''
      action_array=(
        'done'
        'mycroft'
        'prez'             # for when doing a presentation to not reveal sensative info on recording
      )

      until [ "''${action:-}" == 'done' ]; do

        PS3='Action to process? '

        printf '\n\n%s\n' "Select an action to do:" >&2

        select action in "''${action_array[@]}"; do

          if [[ "$action" == "done" ]]; then

            echo "Finishing automation."
            break

          elif [[ -n "$action" ]]; then

            printf 'You chose number %s, processing %s\n' "''${REPLY}" "''${action}"
            ''${action}
            break

          else

            echo "Invalid selection, please try again."

          fi

        done
      done
      unset PS3
    '';
    mycroft_remote_prep.exec = ''
      # https://elrey.casa/bash/scripting/harden
      set -euxo pipefail
      ssh-copy-id tars@192.168.8.99
    '';
    mycroft_ansible.exec = ''
      set -euxo pipefail
      uv sync
      source .devenv/state/venv/bin/activate
      ansible-galaxy collection install -r requirements.yml
      ansible-galaxy role install -r requirements.yml
      ansible-playbook -K -i inventory.yml playbooks/base-playbook.yml
      ansible-playbook -i inventory.yml main-playbook.yml
    '';
    mycroft.exec = ''
      # ssh_prep
      mycroft_remote_prep
      mycroft_ansible
    '';
    # ssh_prep.exec = ''
    #   set -euxo pipefail
    #   read -rp 'What is the name of your ssh key? ' SSH_KEYZ
    #   export FULL_SSH_KEY_PATH="$HOME/.ssh/$SSH_KEYZ"
    #   eval "$(ssh-agent -s)" && ssh-add $FULL_SSH_KEY_PATH
    #   printf '\nUse the following command to use the ssh agent outside of this script:\n'
    #   printf 'export %s\n\n' "$(env | grep -E '(SSH_AUTH_SOCK|SSH_AGENT_PID)=' | tr '\n' ' ')"
    # '';
    prez.exec = ''
      set -x
      export PREZ=true PS1='$ '
      set +x'';
  };


  enterShell = ''
    eval "$(direnv hook bash)"
    proj_select
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # # https://devenv.sh/tests/
  # enterTest = ''
  #   echo "Running tests"
  #   git --version | grep --color=auto "${pkgs.git.version}"
  # '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
