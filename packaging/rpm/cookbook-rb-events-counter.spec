%global cookbook_path /var/chef/cookbooks/rb-events-counter

Name: cookbook-rb-events-counter
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Events-counter cookbook to install and configure it in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-events-counter
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%{cookbook_path}
cp -f -r  resources/* %{buildroot}%{cookbook_path}
chmod -R 0755 %{buildroot}%{cookbook_path}
install -D -m 0644 README.md %{buildroot}%{cookbook_path}/README.md

%pre
if [ -d /var/chef/cookbooks/rb-events-counter ]; then
    rm -rf /var/chef/cookbooks/rb-events-counter
fi

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload rbevents-counter'
  ;;
esac

%postun
# Deletes directory when uninstall the package
if [ "$1" = 0 ] && [ -d /var/chef/cookbooks/rb-events-counter ]; then
  rm -rf /var/chef/cookbooks/rb-events-counter
fi

%files
%defattr(0755,root,root)
%{cookbook_path}
%defattr(0644,root,root)
%{cookbook_path}/README.md

%doc

%changelog
* Thu Oct 10 2024 Miguel Negrón <manegron@redborder.com>
- Add pre and postun

* Tue Oct 5 2021 Miguel Negron <manegron@redborder.com>
- first spec version
