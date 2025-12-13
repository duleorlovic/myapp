# input variables:
- echo "StartWorker `date`" >> /root/cloud_init_script.log
# https://askubuntu.com/questions/1470010/unable-to-create-systemd-user-service-failed-to-connect-to-bus-permission-deni
# https://superuser.com/a/1598351/877698
# loginctl enable-linger ubuntu
- sudo -u ubuntu mkdir -p /home/ubuntu/.config/systemd/user/
- cp /root/prepare_files_for_ubuntu_user/.config/systemd/user/sidekiq.service /home/ubuntu/.config/systemd/user/sidekiq.service
- chown ubuntu:ubuntu /home/ubuntu/.config/systemd/user/sidekiq.service
# TODO: on this line I got error: Failed to connect to bus: No such file or directory
- sudo -u ubuntu XDG_RUNTIME_DIR=/run/user/$(id -u ubuntu) systemctl --user daemon-reload
- sudo -u ubuntu XDG_RUNTIME_DIR=/run/user/$(id -u ubuntu) systemctl --user enable sidekiq.service
# - sudo -u ubuntu XDG_RUNTIME_DIR=/run/user/$(id -u ubuntu) systemctl --user start sidekiq.service
- echo "FinishWorker" >> /root/cloud_init_script.log
