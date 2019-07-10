# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

    config.vm.provider "virtualbox" do |v|
        v.memory = 4096
        v.cpus = 4
    end

    # import complete db on up
    config.trigger.after :up do |trigger|
        trigger.run_remote = {inline: "cd /var/www/; mysql -u root -proot < alldb.sql"}
    end

    # export complete db on halt
    config.trigger.before :halt do |trigger|
        trigger.run_remote = {inline: "cd /var/www/; mysqldump -u root -proot --all-databases > alldb.sql"}
    end

    config.vm.box = "bento/ubuntu-18.04"

    config.vm.hostname = "box"

    config.vm.network "private_network", ip: "192.168.33.10"

    config.vm.synced_folder "www", "/var/www",
        #type: "nfs",
        mount_options: ["dmode=777", "fmode=666"]

    config.ssh.insert_key = true

    config.vm.provision "shell", path: "install.sh", privileged: false

end
