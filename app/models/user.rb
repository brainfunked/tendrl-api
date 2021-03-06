module Tendrl
  class User

    ADMIN = 'admin'
    NORMAL = 'normal'
    LIMITED = 'limited'

    ROLES = [ADMIN, NORMAL, LIMITED]

    attr_accessor :name, :email, :username, :role, :password_hash,
      :password_salt, :email_notifications

    def initialize(attributes={})
      @name = attributes[:name]
      @email = attributes[:email]
      @username = attributes[:username]
      @email_notifications = attributes[:email_notifications]
      @role = attributes[:role]
      @password_hash = nil
      @password_salt = nil
    end

    def attributes
      {
        name: name,
        email: email,
        username: username,
        email_notifications: email_notifications,
        role: role
      }
    end

    def admin?
      @role == ADMIN
    end

    def normal?
      admin? || @role == NORMAL
    end

    def limited?
      @role == LIMITED
    end

    def generate_token
      token = SecureRandom.hex(32)
      Tendrl.etcd.set(
        "/_tendrl/access_tokens/#{token}",
        value: username,
        ttl: 604800 # 1.week
      )
      token
    end

    def delete_token(access_token)
      Tendrl.etcd.delete("/_tendrl/access_tokens/#{access_token}")
    end

    def new_record?
      password_hash.blank?
    end

    def delete
      Tendrl.etcd.delete("/_tendrl/users/#{username}", recursive: true)
    end

    class << self

      def all
        begin
          users = []
          Tendrl.etcd.get("/_tendrl/users", recursive: true).children.each do
            |child|
            attributes = {}
            child.children.each do |attribute|
              attributes[attribute.key.split('/')[-1].to_sym] = attribute.value
            end
            users << new(attributes)
          end
        rescue Etcd::KeyNotFound
        end
        users
      end

      def find(username)
        attributes = {}
        Tendrl.etcd.get("/_tendrl/users/#{username}").
          children.each do |child|
          attributes[child.key.split('/')[-1].to_sym] = child.value
        end
        user = new(attributes)
        user.password_hash = attributes[:password_hash]
        user.password_salt = attributes[:password_salt]
        user
      rescue Etcd::KeyNotFound
        nil
      end

      def find_user_by_access_token(token)
        username = Tendrl.etcd.get("/_tendrl/access_tokens/#{token}").value
        find(username)
      rescue Etcd::KeyNotFound
        nil
      end

      def save(attributes)
        password = attributes.delete(:password)
        if password
          password_salt = BCrypt::Engine.generate_salt
          password_hash = BCrypt::Engine.hash_secret(
            password, password_salt
          )
          attributes.merge!(
            password_salt: password_salt,
            password_hash: password_hash
          )
        end
        begin
          Tendrl.etcd.set(
            "/_tendrl/users/#{attributes[:username]}",
            dir: true
          )
        rescue Etcd::NotFile
          # Exception for existing username, so update
        end
        attributes.each do |key, value|
          Tendrl.etcd.set("/_tendrl/users/#{attributes[:username]}/#{key}", value: value)
        end
        user = find(attributes[:username])
        post_save_hooks(user)
        user
      end

      def post_save_hooks(user)
        update_email_notification_indexes(user)
      end

      def update_email_notification_indexes(user)
        if user.email_notifications == "true"
          Tendrl.etcd.set("/_tendrl/indexes/notifications/email_notifications/#{user.username}",
                        value: user.email)
        end
      end

      def authenticate(username, password)
        user = find(username)
        if user && user.password_hash == BCrypt::Engine.hash_secret(password, user.password_salt)
          user
        else
          nil
        end
      end

      def authenticate_access_token(access_token)
        if user = find_user_by_access_token(access_token)
          user
        else
          nil
        end
      rescue Etcd::KeyNotFound
        nil
      end

    end
  end
end
