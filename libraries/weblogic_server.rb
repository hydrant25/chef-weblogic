#
# Cookbook Name:: weblogic
# Resource:: weblogic-server
#
# Copyright (C) 2015 University of Derby
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Interface for this should look like:
# weblogic '12.1.2.0.0'
#
Chef.resource 'weblogic' do
  include Chef::DSL::IncludeRecipe

  property :version, String, identity: true
  property :cache_path, Path do
    default { ::File.join(Chef::Config[:file_cache_path], "weblogic-#{version}") }
  end
  property :silent_path, Path do
    default { ::File.join(cache_path, silent_file) }
  end
  property :silent_file, Path do
    default do
      if Gem::Version.new(version) < Gem::Version.new('12.1.2.0.0')
        'silent.xml'
      else
        'silent.rsp'
      end
    end
  end
  property :silent_cmd, String do
    default do
      if Gem::Version.new(version) < Gem::Version.new('12.1.2.0.0')
        '-mode=silent -silent_xml='
      else
        '-silent -responseFile '
      end
    end
  end
  property :component_paths, String do
    default do
      v = Gem::Version.new(version)
      v1211 = Gem::Version.new('12.1.1')
      v1212 = Gem::Version.new('12.1.2')
      case
      when v >= v1211 && v < v1212
        'WebLogic Server/Core Application Server|WebLogic Server/Administration Console|WebLogic Server/Configuration Wizard and Upgrade Framework|WebLogic Server/Web 2.0 HTTP Pub-Sub Server|WebLogic Server/WebLogic JDBC Drivers|WebLogic Server/Third Party JDBC Drivers|WebLogic Server/WebLogic Server Clients|WebLogic Server/Xquery Support|WebLogic Server/Server Examples'
      else
        'WebLogic Server/Core Application Server|WebLogic Server/Administration Console|WebLogic Server/Configuration Wizard and Upgrade Framework|WebLogic Server/Web 2.0 HTTP Pub-Sub Server|WebLogic Server/WebLogic JDBC Drivers|WebLogic Server/Third Party JDBC Drivers|WebLogic Server/WebLogic Server Clients|WebLogic Server/WebLogic Web Server Plugins|WebLogic Server/UDDI and Xquery Support|WebLogic Server/Server Examples'
      end
    end
  end
  property :installer_url, String do
    default { node['common_artifact_repo'] + "/oracle/weblogic-server/#{version}/#{installer_file}" }
  end
  property :installer_path, Path do
    default {  ::File.join(cache_path, installer_file) }
  end
  property :installer_file, Path do
    default do
      v = Gem::Version.new(version)
      v1036 = Gem::Version.new('10.3.6')
      v1211 = Gem::Version.new('12.1.1')
      v1212 = Gem::Version.new('12.1.2')
      v1213 = Gem::Version.new('12.1.3')
      case
      when v >= v1036 && v < v1211
        'wls1036_generic.jar'
      when v >= v1211 && v < v1212
        'wls1211_generic.jar'
      when v >= v1212 && v < v1213
        'wls_121200.jar'
      else
        'fmw_12.1.3.0.0_wls.jar'
      end
    end
  end
  property :ownername, String do
    default { 'oracle' }
  end
  property :groupname, String do
    default { 'dba' }
  end
  property :home, Path do
    default { "/opt/oracle/Middleware/weblogic-#{version}" }
  end
  property :oracle_jdk, String do
    default { 7 }
  end
  property :inventory_path, Path do
    default { ::File.join(home, 'oraInventory') }
  end
  
  def manage_java(arg=true)
    set_or_return(:manage_java, arg, :kind_of => [TrueClass, FalseClass])
  end

  recipe do
    node.default['java']['jdk_version'] = oracle_jdk
    node.default['java']['install_flavor'] = 'oracle'
    node.default['java']['oracle']['accept_oracle_download_terms'] = true
    include_recipe 'java' unless manage_java

    if Gem::Version.new(version) >= Gem::Version.new('12.1.2.0.0')
      include_recipe 'oracle-inventory'
      group node['oracle']['inventory']['group'] do
        append true
        members ownername
      end
    end

    group groupname

    user ownername do
      gid groupname
    end

    directory cache_path do
      mode 00775
      owner ownername
      group groupname
      recursive true
    end

    directory home do
      mode 00775
      owner ownername
      group groupname
      recursive true
    end

    remote_file installer_path do
      mode 00644
      owner ownername
      group groupname
      source installer_url
    end

    template silent_path do
      mode 00644
      owner owner
      group groupname
      source silent_file + '.erb'
      cookbook 'weblogic'
      variables(
        home: home,
        component_paths: component_paths
      )
    end

    execute "install weblogic server #{version}" do
      user ownername
      group groupname
      command "java -jar #{installer_path}  #{silent_cmd}#{silent_path}"
      only_if { Dir["#{home}/*"].empty? }
    end
  end
end
