# Cookbook:: rbevents-counter
# Provider:: config

include RbEventscounter::Helper

action :add do
  begin
    user = new_resource.user

    dnf_package 'redborder-events-counter' do
      action :upgrade
      flush_cache [:before]
    end

    execute 'create_user' do
      command "/usr/sbin/useradd -r #{user}"
      ignore_failure true
      not_if "getent passwd #{user}"
    end

    %w(/etc/redborder-events-counter).each do |path|
      directory path do
        owner user
        group user
        mode '0755'
        action :create
      end
    end

    # Licenses configuration
    directory '/etc/licenses' do
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end

    begin
      licmode_dg = data_bag_item('rBglobal', 'licmode')
    rescue
      licmode_dg = {}
    end

    licmode = licmode_dg['mode']
    if licmode != 'global' && licmode != 'organization'
      licmode = 'global'
    end

    begin
      licenses_dg = data_bag_item('rBglobal', 'licenses')
    rescue
      licenses_dg = {}
    end

    licenses_dg['licenses'].each do |uuid, value|
      template "/etc/licenses/#{uuid}" do
        source 'variable.erb'
        owner 'root'
        group 'root'
        cookbook 'rbevents-counter'
        mode '0644'
        retries 2
        variables(variable: JSON.pretty_generate(value))
        notifies :restart, 'service[redborder-events-counter]', :delayed
      end
    end unless licenses_dg['licenses'].nil?

    template '/etc/redborder-events-counter/config.yml' do
      source 'config.yml.erb'
      owner user
      group user
      mode '0644'
      ignore_failure true
      cookbook 'rbevents-counter'
      variables(licmode: licmode)
      notifies :restart, 'service[redborder-events-counter]', :delayed
    end

    begin
      root_pem = data_bag_item('certs', 'root')
    rescue
      root_pem = nil
    end

    if root_pem && root_pem['private_rsa']
      template '/etc/redborder-events-counter/admin.pem' do
        source 'rsa_cert.pem.erb'
        owner user
        group user
        mode '0600'
        retries 2
        variables(private_rsa: root_pem['private_rsa'])
        cookbook 'rbevents-counter'
      end
    end

    service 'redborder-events-counter' do
      service_name 'redborder-events-counter'
      ignore_failure true
      supports status: true, restart: true, enable: true
      action [:start, :enable]
    end

    Chef::Log.info('rb-Events-counter cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    service 'redborder-events-counter' do
      service_name 'redborder-events-counter'
      ignore_failure true
      supports status: true, enable: true
      action [:stop, :disable]
    end

    %w(/etc/redborder-events-counter).each do |path|
      directory path do
        recursive true
        action :delete
      end
    end

    dnf_package 'redborder-events-counter' do
      action :remove
    end

    Chef::Log.info('rb-Events-counter cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    unless node['redborder-events-counter']['registered']
      query = {}
      query['ID'] = "redborder-events-counter-#{node['hostname']}"
      query['Name'] = 'redborder-events-counter'
      query['Address'] = "#{node['ipaddress']}"
      query['Port'] = '5000'
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['redborder-events-counter']['registered'] = true
      Chef::Log.info('redborder-events-counter service has been registered to consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    if node['redborder-events-counter']['registered']
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/redborder-events-counter-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['redborder-events-counter']['registered'] = false
      Chef::Log.info('redborder-events-counter service has been deregistered from consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
