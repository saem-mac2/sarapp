# Lock to a specific Capistrano version
lock "~> 3.19.2"

set :application, "my_app_name"
set :repo_url, "git@github.com:saem-mac2/tesgub.git"

# Directory to deploy to on the server
set :deploy_to, "/home/deploy/#{fetch(:application)}"

# Server user
set :user, "deploy"

# Linked directories (persist between deploys)
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "vendor/bundle", ".bundle", "public/system", "public/uploads"

# Number of releases to keep
set :keep_releases, 5

# SSH options
set :ssh_options, {
  auth_methods: ['publickey'],
  keys: ['./server_key'],
  forward_agent: false,
  verify_host_key: :never
}

# Passenger role
set :passenger_roles, :web

# Sidekiq roles if applicable
set :sidekiq_roles, [:sidekiq_worker]

# Custom bundler configuration
set :bundle_flags, '--quiet'
set :bundle_path, -> { shared_path.join('vendor/bundle') }
set :bundle_without, %w[development test].join(' ')

namespace :deploy do
  desc "Set up bundler"
  task :config_bundler do
    on roles(:all) do
      execute :bundle, :config, "--local deployment true"
      execute :bundle, :config, "--local without development test"
      execute :bundle, :config, "--local path vendor"
    end
  end

  task :symlink_rbenv_vars do
    on roles(:app) do
      execute "ln -s /home/deploy/#{fetch(:application)}/.rbenv-vars #{current_path}/."
    end
  end
end

before "bundler:install", "deploy:config_bundler"
after "deploy", "deploy:symlink_rbenv_vars"

before "deploy:starting", "deploy:install_github_key"

namespace :deploy do
  desc "Install GitHub deploy key on remote"
  task :install_github_key do
    on roles(:all) do
      execute :mkdir, "-p", "~/.ssh"
      execute :chmod, "700", "~/.ssh"

      # Upload from inside the container's /app dir
      upload! "/app/github_key", "/home/deploy/.ssh/github_key"
      execute :chmod, "600", "/home/deploy/.ssh/github_key"

      # Write SSH config
      ssh_config = <<~CONFIG
        Host github.com
          IdentityFile /home/deploy/.ssh/github_key
          StrictHostKeyChecking no
          UserKnownHostsFile=/dev/null
      CONFIG

      execute %(echo "#{ssh_config.gsub("\n", "\\n")}" > ~/.ssh/config)
    end
  end

  # get ride of the key now
  task :cleanup_github_key do
    on roles(:all) do
      execute :rm, "-f", "~/.ssh/github_key"
    end
  end
end

after "deploy:finished", "deploy:cleanup_github_key"

set :git_environmental_variables, {
  GIT_SSH_COMMAND: "ssh -i ~/.ssh/github_key -o StrictHostKeyChecking=no"
}
