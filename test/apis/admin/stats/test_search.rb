require_relative "../../../test_helper"

class Test::Apis::Admin::Stats::TestSearch < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_bins_results_by_day_with_time_zone_support
    Time.use_zone("America/Denver") do
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-12T23:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-13T00:00:00"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-18T23:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-19T00:00:00"))
    end
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Tue, Jan 13, 2015", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1421132400000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Jan 18, 2015", data["hits_over_time"][5]["c"][0]["f"])
    assert_equal(1421564400000, data["hits_over_time"][5]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][5]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][5]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_begin
    LogItem.index_name = "api-umbrella-logs-write-2015-03"
    Time.use_zone("UTC") do
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T00:00:00"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-09T10:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-07",
        :end_at => "2015-03-09",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(4, data["stats"]["total_hits"])
    assert_equal("Sat, Mar 7, 2015", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1425711600000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Mon, Mar 9, 2015", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1425880800000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_begin
    LogItem.index_name = "api-umbrella-logs-write-2015-03"
    Time.use_zone("UTC") do
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-08",
        :end_at => "2015-03-08",
        :interval => "hour",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Sun, Mar 8, 2015 12:00am MST", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 1:00am MST", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1425801600000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 3:00am MDT", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1425805200000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 4:00am MDT", data["hits_over_time"][3]["c"][0]["f"])
    assert_equal(1425808800000, data["hits_over_time"][3]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][3]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][3]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_end
    LogItem.index_name = "api-umbrella-logs-write-2014-11"
    Time.use_zone("UTC") do
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T00:00:00"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-03T10:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-01",
        :end_at => "2014-11-03",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(4, data["stats"]["total_hits"])
    assert_equal("Sat, Nov 1, 2014", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1414821600000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1414908000000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Mon, Nov 3, 2014", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1414998000000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_end
    LogItem.index_name = "api-umbrella-logs-write-2014-11"
    Time.use_zone("UTC") do
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-02",
        :end_at => "2014-11-02",
        :interval => "hour",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Sun, Nov 2, 2014 1:00am MDT", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1414911600000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 1:00am MST", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1414915200000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 2:00am MST", data["hits_over_time"][3]["c"][0]["f"])
    assert_equal(1414918800000, data["hits_over_time"][3]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][3]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][3]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 3:00am MST", data["hits_over_time"][4]["c"][0]["f"])
    assert_equal(1414922400000, data["hits_over_time"][4]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][4]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][4]["c"][1]["v"])
  end
end
