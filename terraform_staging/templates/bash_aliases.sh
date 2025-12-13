# Start of code from: https://trk.tools/tf/cloud-init-tips/-/blob/main/README.md
alias c=cloud-init
alias cf="cloud-init modules -m final"
alias cl="tail -f /var/log/cloud-init-output.log"
alias cr="less /var/lib/cloud/instance/scripts/runcmd"
alias call="cloud-init clean --logs && cloud-init init && cloud-init modules && cloud-init modules -m final"
# End of code from: https://trk.tools/tf/cloud-init-tips/-/blob/main/README.md
alias be="bundle exec"
