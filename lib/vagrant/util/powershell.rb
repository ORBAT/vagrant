require_relative "subprocess"
require_relative "which"

module Vagrant
  module Util
    # Executes PowerShell scripts.
    #
    # This is primarily a convenience wrapper around Subprocess that
    # properly sets powershell flags for you.
    class PowerShell
      def self.available?
        !!Which.which("powershell")
      end

      # Execute a powershell script.
      #
      # @param [String] path Path to the PowerShell script to execute.
      # @return [Subprocess::Result]
      def self.execute(path, *args, **opts, &block)
        command = [
          "powershell",
          "-NoProfile",
          "-ExecutionPolicy", "Bypass",
          "&('#{path}')",
          args
        ].flatten

        # Append on the options hash since Subprocess doesn't use
        # Ruby 2.0 style options yet.
        command << opts

        Subprocess.execute(*command, &block)
      end
    end
  end
end
