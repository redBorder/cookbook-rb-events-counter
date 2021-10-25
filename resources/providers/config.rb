
# Cookbook Name:: events-counter
#
# Provider:: config
#

include Eventscounter::Helper

action :add do
  begin

    user = new_resource.user
    cdomain = new_resource.cdomain

    yum_package "events-counter" do
      action :upgrade
      flush_cache [:before]
    end

    user user do
      action :create
      system true
    end

    flow_nodes = []

    %w[ /etc/events-counter].each do |path|
      directory path do
        owner user
        group user
        mode 0755
        action :create
      end
    end

    # Licenses configuration
    directory "/etc/licenses" do
      owner "root"
      group "root"
      mode 0755
      action :create
    end

    licmode_dg = Chef::EncryptedDataBagItem.load("rBglobal", "licmode") rescue licmode_dg={}
    licmode = licmode_dg["mode"]
    licmode = "global" if (licmode!="global" and licmode!="organization")

    licenses_dg = Chef::DataBagItem.load("rBglobal", "licenses") rescue licenses_dg={}

    licenses_dg["licenses"].each do |uuid, value|
      template "/etc/licenses/#{uuid}" do
        source "variable.erb"
        owner "root"
        group "root"
        cookbook "events-counter"
        mode 0644
        retries 2
        variables(:variable => JSON.pretty_generate(value))
        notifies :reload, "service[events-counter]", :delayed
      end
    end unless licenses_dg["licenses"].nil?

    template "/etc/events-counter/config.yml" do
      source "config.yml.erb"
      owner user
      group user
      mode 0644
      ignore_failure true
      cookbook "events-counter"
      variables(:licmode => licmode)
      notifies :restart, "service[events-counter]", :delayed
    end

    root_pem = Chef::EncryptedDataBagItem.load("certs", "root") rescue root_pem = nil

    if !root_pem.nil? and !root_pem["private_rsa"].nil?
      template "/etc/events-counter/admin.pem" do
        source "rsa_cert.pem.erb"
        owner user
        group user
        mode 0600
        retries 2
        variables(:private_rsa => root_pem["private_rsa"])
        cookbook "events-counter"
      end
    end


    service "events-counter" do
      service_name "events-counter"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true, :enable => true
      action [:start, :enable]
    end

    Chef::Log.info("Events-counter cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    
    service "events-counter" do
      service_name "events-counter"
      ignore_failure true
      supports :status => true, :enable => true
      action [:stop, :disable]
    end

    %w[ /etc/events-counter ].each do |path|
      directory path do
        recursive true
        action :delete
      end
    end

    yum_package "events-counter" do
      action :remove
    end

    Chef::Log.info("Events-counter cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    if !node["events-counter"]["registered"]
      query = {}
      query["ID"] = "events-counter-#{node["hostname"]}"
      query["Name"] = "events-counter"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = "5000"
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
         command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
         action :nothing
      end.run_action(:run)

      node.set["events-counter"]["registered"] = true
      Chef::Log.info("Events-counter service has been registered to consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    if node["events-counter"]["registered"]
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/events-counter-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["events-counter"]["registered"] = false
      Chef::Log.info("Events-counter service has been deregistered from consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
