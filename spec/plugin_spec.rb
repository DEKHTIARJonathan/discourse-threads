# frozen_string_literal: true

RSpec.describe DiscourseThreads do
  describe "site settings" do
    it "lists nested replies with the plugin settings", :aggregate_failures do
      expected_description =
        [
          "Enable nested replies. This setting is required and automatically managed",
          "by Threads while the plugin is enabled."
        ].join(" ")
      plugin_settings = SiteSetting.all_settings(filter_plugin: "discourse-threads")
      nested_replies_setting =
        plugin_settings.find do |setting|
          setting[:setting] == :nested_replies_enabled
        end

      expect(nested_replies_setting).to include(
        category: "discourse_threads",
        default: "true",
        description: expected_description,
        plugin: "discourse-threads",
        value: "true"
      )
      expect(SiteSetting.client_settings).to include(:nested_replies_enabled)
    end

    it "enables required settings on a fresh install", :aggregate_failures do
      expect(SiteSetting.discourse_threads_enabled).to eq(true)
      expect(SiteSetting.nested_replies_enabled).to eq(true)
    end

    it "rejects false values for nested replies while active", :aggregate_failures do
      [false, nil, "false", "0", 0, "f"].each do |value|
        expect { SiteSetting.nested_replies_enabled = value }.to raise_error(
          Discourse::InvalidParameters,
          /nested_replies_enabled is required while Threads is enabled/
        )
      end

      expect(SiteSetting.nested_replies_enabled).to eq(true)
    end

    it "rejects direct overrides that disable nested replies while active" do
      expect do
        SiteSetting.add_override!(:nested_replies_enabled, false)
      end.to raise_error(
        Discourse::InvalidParameters,
        /nested_replies_enabled is required while Threads is enabled/
      )
    end

    it "allows nested replies to be disabled when the plugin is disabled" do
      SiteSetting.discourse_threads_enabled = false

      expect { SiteSetting.nested_replies_enabled = false }.not_to raise_error
      expect(SiteSetting.nested_replies_enabled).to eq(false)
    end

    it "enforces required settings on boot without forcing core default mode",
       :aggregate_failures do
      SiteSetting.discourse_threads_enabled = false
      SiteSetting.nested_replies_enabled = false
      SiteSetting.nested_replies_default = false
      SiteSetting.current[:discourse_threads_enabled] = true

      described_class.enforce_required_site_settings

      expect(SiteSetting.nested_replies_enabled).to eq(true)
      expect(SiteSetting.nested_replies_default).to eq(false)
    ensure
      SiteSetting.current.delete(:discourse_threads_enabled)
      SiteSetting.discourse_threads_enabled = true if !SiteSetting.discourse_threads_enabled
    end

    it "restores nested replies when the plugin is re-enabled without forcing core default mode",
       :aggregate_failures do
      SiteSetting.discourse_threads_enabled = false
      SiteSetting.nested_replies_enabled = false
      SiteSetting.nested_replies_default = false

      SiteSetting.discourse_threads_enabled = true

      expect(SiteSetting.nested_replies_enabled).to eq(true)
      expect(SiteSetting.nested_replies_default).to eq(false)
    end

    it "keeps nested replies enabled when the override is removed while active" do
      SiteSetting.discourse_threads_enabled = false
      SiteSetting.nested_replies_enabled = false
      SiteSetting.discourse_threads_enabled = true

      SiteSetting.remove_override!(:nested_replies_enabled)

      expect(SiteSetting.nested_replies_enabled).to eq(true)
    end
  end
end
