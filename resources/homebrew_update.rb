unified_mode true if respond_to? :unified_mode

provides :homebrew_update

description "Use the **homebrew_update** resource to manage Homebrew repository updates on MacOS."
introduced "16.2"
examples <<~DOC
  **Update the hombrew repository data at a specified interval**:
  ```ruby
  homebrew_update 'all platforms' do
    frequency 86400
    action :periodic
  end
  ```
  **Update the Homebrew repository at the start of a Chef Infra Client run**:
  ```ruby
  homebrew_update 'update'
  ```
DOC

# allow bare homebrew_update with no name
property :name, String, default: ""

property :frequency, Integer,
  description: "Determines how frequently (in seconds) Homebrew updates are made. Use this property when the `:periodic` action is specified.",
  default: 86_400

default_action :periodic
allowed_actions :update, :periodic

action_class do
  BREW_STAMP_DIR = "/var/lib/homebrew/periodic".freeze
  BREW_STAMP = "#{BREW_STAMP_DIR}/update-success-stamp".freeze

  # Determines whether we need to run `homebrew update`
  #
  # @return [Boolean]
  def brew_up_to_date?
    ::File.exist?(BREW_STAMP) &&
      ::File.mtime(BREW_STAMP) > Time.now - new_resource.frequency
  end

  def do_update
    directory BREW_STAMP_DIR do
      recursive true
    end

    file BREW_STAMP do
      content "BREW::Update::Post-Invoke-Success\n"
      action :create_if_missing
    end

    execute "brew update" do
      command [ "brew", "update" ]
      default_env true
      user Homebrew.owner
      notifies :touch, "file[BREW_STAMP]", :immediately
    end
  end
end

action :periodic do
  return unless mac_os_x?

  unless brew_up_to_date?
    converge_by "update new lists of packages" do
      do_update
    end
  end
end

action :update do
  return unless mac_os_x?

  converge_by "force update new lists of packages" do
    do_update
  end
end
