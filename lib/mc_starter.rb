require 'fileutils'
require 'erb'

module McStarter
  def self.start!(options)
    raise "Bad parameters" if options[:port].nil? or options[:nick].nil? or options[:server_name].nil?

    # Z MC_HOME nastavíme kde budou servery
    home_dir = ENV['MC_HOME']
    # V MC_HOME/source je šablona pro servery
    source_dir = File.join(home_dir, 'source')
    # Složka pro nový server
    server_dir = File.join(home_dir, 'servers', options[:port].to_s)
    # Složka s pluginy
    server_plugins_dir = File.join(server_dir, 'plugins')
    # NoLagg soubor
    no_lagg_file = File.join(server_plugins_dir, 'NoLagg.jar')
    # Složka pro zálohy
    backup_dir = File.join(home_dir, 'backups')
    # Složka serveru v zálohách
    server_backup_dir = File.join(backup_dir, options[:port].to_s)
    # uživatel pod kterým to poběží
    user = "retro"

    # smažeme složky serveru a zálohy, pokud existují
    FileUtils.rm_rf(server_dir) if File.directory?(server_dir)
    FileUtils.rm_rf(server_backup_dir) if File.directory?(server_backup_dir)

    begin
    # vytvorim si slozku cisty server : cp -r /home/hosting/source /home/hosting/servers/$port
    FileUtils.mkdir_p(server_dir)
    FileUtils.cp_r(File.join(source_dir, '.'), server_dir)

    # vytvorim si backup slozku : mkdir /home/hosting/backups/$port
    FileUtils.mkdir_p(server_backup_dir)

    # propojim se serverem : ln -s /home/hosting/servers/$port /home/hosting/backups/$port
    system ("ln -s #{server_dir} #{server_backup_dir}")

    # pridame si uzivatele : useradd $username -D /home/hosting/servery/$port/plugins
    `/usr/sbin/useradd #{options[:nick]} -D #{server_plugins_dir}` rescue puts "User not created!"

    # vytvorime users.yml v /home/hosting/servery/$port/plugins/GroupManager/worlds/world a ostatních složkách
    template = ERB.new(IO.read(File.expand_path('../views/users.yml.erb', File.dirname(__FILE__))))
    ["#{options[:server_name]}_nether", "#{options[:server_name]}_the_end", "#{options[:server_name]}"].each do |dir|
      plugin_dir = File.join(server_plugins_dir, 'GroupManager', 'worlds', dir)
      FileUtils.mkdir_p(plugin_dir)
      File.open(File.join(plugin_dir, 'users.yml'), 'wb') {|f| f.write(template.result(binding)) }
    end

    # vytvorime config.yml v /home/hosting/servery/$port/plugins/MinecraftViewer/
    template = ERB.new(IO.read(File.expand_path('../views/config.yml.erb', File.dirname(__FILE__))))
    plugin_dir = File.join(server_plugins_dir, 'MinecraftViewer')
    FileUtils.mkdir_p(plugin_dir)
    File.open(File.join(plugin_dir, 'config.yml'), 'wb') {|f| f.write(template.result(binding)) }

    # na konec souboru : /home/hosting/servery/$port/plugins/dynmap/configuration.txt doplnime :
    # webserver-port: $port+1
    File.open(File.join(server_plugins_dir, 'dynmap', 'configuration.txt'), 'a') {|f| f.write("\nwebserver-port: #{options[:port] + 1}")}

    # zmenime prava : chown -R 777 /home/hosting/servery/$port/plugins
    FileUtils.chmod_R(0777, server_plugins_dir)

    # zmenime prava : chown -R 444 /home/hosting/servery/$port/plugins/NoLagg.jar
    File.chmod(0444, no_lagg_file)

    # zmenime prava : chmod ruby:ruby /home/hosting/servery/$port/plugins/NoLagg.jar
    `chown #{user}:#{user} #{no_lagg_file}`

    # pokud něco nedopadne uplně nejlíp, tak to prostě všechno smažeme
    rescue Exception => e
      puts `tree #{home_dir}`
      puts "Error!"
      puts "#{ e } (#{ e.class })!"
      puts "#{ e.backtrace.join("\n") }"
      puts "Deleting data"
      FileUtils.rm_rf(server_dir)
      FileUtils.rm_rf(server_backup_dir)
    end
  end
end
