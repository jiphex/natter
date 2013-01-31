require "bundler/capistrano"

set :application, "natter"
set :repository,  "git@github.com:jiphex/natter.git"

set :deploy_via, :remote_cache
set :scm, :git

set :user, "james"

server "drax.tlyk.eu", :app, :redis
set :deploy_to, "/srv/ruby/comments"

set :use_sudo, false

ssh_options[:keys] = %w('~/.ssh/id_rsa.pub')

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end
