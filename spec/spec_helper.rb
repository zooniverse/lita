require "lita/rspec"

$:.unshift(File.expand_path("../../handlers", __FILE__))

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false
