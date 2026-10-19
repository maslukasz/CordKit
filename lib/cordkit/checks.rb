# frozen_string_literal: true

module CordKit
  # A single command check. Return a truthy value to allow the command,
  # or raise {CheckFailed} with a message to reject it.
  class Check
    # @return [String, nil]
    attr_reader :name

    # @return [String, nil]
    attr_reader :message

    # @return [Proc]
    attr_reader :block

    def initialize(name: nil, message: nil, &block)
      raise ArgumentError, "A check requires a block" unless block

      @name = name
      @message = message
      @block = block
    end

    # @param context [CordKit::Context]
    # @return [Boolean]
    def call(context)
      result = block.call(context)
      return true if result

      raise CheckFailed, message
    rescue CheckFailed
      raise
    rescue StandardError => e
      raise CheckFailed, (message || e.message)
    end
  end

  # Factory methods for common checks.
  module Checks
    module_function

    # @return [CordKit::Check]
    def custom(name: nil, message: nil, &block)
      Check.new(name: name, message: message, &block)
    end

    # @return [CordKit::Check]
    def guild_only(message: "This command can only be used in a server.")
      custom(name: :guild_only, message: message) { |ctx| !ctx.server.nil? }
    end

    # @return [CordKit::Check]
    def dm_only(message: "This command can only be used in DMs.")
      custom(name: :dm_only, message: message) { |ctx| ctx.server.nil? }
    end

    # Requires Discord permissions. Administrator and server owner bypass the check.
    # @param permissions [Array<Symbol>]
    # @return [CordKit::Check]
    def user_permissions(*permissions, any: false, message: nil, &resolver)
      permissions = permissions.flatten
      custom(name: :user_permissions,
             message: message || "You need the following permissions: #{permissions.join(', ')}.") do |ctx|
        member = ctx.member
        next false unless member

        next yield(ctx) if resolver

        bits = role_permissions(member)
        required = Discordrb::Permissions.bits(permissions)
        any ? bits.anybits?(required) : bits.allbits?(required)
      end
    end

    # Requires permissions from the bot member in the current server.
    # @return [CordKit::Check]
    def bot_permissions(*permissions, any: false, message: nil)
      permissions = permissions.flatten
      custom(name: :bot_permissions,
             message: message || "I need the following permissions: #{permissions.join(', ')}.") do |ctx|
        member = ctx.bot_member
        next false unless member

        bits = role_permissions(member)
        required = Discordrb::Permissions.bits(permissions)
        any ? bits.anybits?(required) : bits.allbits?(required)
      end
    end

    # Requires all (or any) of the given roles. Roles may be IDs, names or Role objects.
    # @return [CordKit::Check]
    def roles(*roles, any: false, message: nil)
      wanted = roles.flatten
      custom(name: :roles, message: message || "You do not have the required role.") do |ctx|
        member = ctx.member
        next false unless member

        held_ids = member.roles.map(&:id)
        held_names = member.roles.map(&:name)
        matches = wanted.map do |role|
          id = role.respond_to?(:id) ? role.id : role.to_i
          held_ids.include?(id) || held_names.include?(role.to_s)
        end
        any ? matches.any? : matches.all?
      end
    end

    # @return [CordKit::Check]
    def users(*user_ids, message: "You are not allowed to use this command.")
      ids = user_ids.flatten.map(&:to_i)
      custom(name: :users, message: message) { |ctx| ids.include?(ctx.user.id) }
    end

    # @return [CordKit::Check]
    def servers(*server_ids, message: "This command is not available in this server.")
      ids = server_ids.flatten.map(&:to_i)
      custom(name: :servers, message: message) { |ctx| ctx.server && ids.include?(ctx.server.id) }
    end

    # @return [CordKit::Check]
    def channels(*channel_ids, message: "This command is not available in this channel.")
      ids = channel_ids.flatten.map(&:to_i)
      custom(name: :channels, message: message) { |ctx| ids.include?(ctx.channel_id) }
    end

    # @return [CordKit::Check]
    def owner_only(ids = nil, message: "Only the bot owner can use this command.")
      custom(name: :owner_only, message: message) do |ctx|
        configured = Array(ids || ctx.config.owner_ids).map(&:to_i)
        configured.include?(ctx.user.id)
      end
    end

    # @return [CordKit::Check]
    def nsfw(message: "This command can only be used in an NSFW channel.")
      custom(name: :nsfw, message: message) { |ctx| ctx.channel&.nsfw? }
    end

    # Returns the role based permission bits for a member.
    # Administrators and server owners are treated as having every permission.
    # @param member [Discordrb::Member]
    # @return [Integer]
    def role_permissions(member)
      all_bits = Discordrb::Permissions::FLAGS.keys.sum { |bit| 2**bit }
      server = member.server
      return all_bits if server && server.owner&.id == member.id

      roles = member.roles
      return all_bits if roles.any? { |role| role.permissions.administrator }

      roles.sum { |role| role.permissions.bits }
    rescue StandardError
      0
    end
  end
end
