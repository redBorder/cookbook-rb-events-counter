# Cookbook:: rbevents-counter
# Resource:: config

actions :add, :remove, :register, :deregister
default_action :add

attribute :user, kind_of: String, default: 'redborder-events-counter'
attribute :cdomain, kind_of: String, default: 'redborder.cluster'
