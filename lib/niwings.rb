require "niwings/version"

require "net/http"
require "openssl"
require "json"
require "base64"
require 'pp'

module Blowfish
  def self.cipher(mode, key, data)
    cipher = OpenSSL::Cipher::Cipher.new('bf-ecb').send(mode)
    cipher.key = Digest::SHA256.digest(key)
    cipher.padding = 1
    cipher.update(data) << cipher.final
  end

  def self.encrypt(key, data)
    cipher(:encrypt, key, data)
  end

  def self.decrypt(key, text)
    cipher(:decrypt, key, text)
  end
end


module Niwings
  #BASE_URL = "https://gdcportalgw.its-mo.com/gworchest_0307C/gdc"
  BASE_URL = "https://gdcportalgw.its-mo.com/gworchest_0323A/gdc"
  COUNTRY_USA = "NNA"
  COUNTRY_CAN = "NCI"
  COUNTRY_EUR = "NE"
  COUNTRY_AUS = "NMA"
  COUNTRY_JAP = "NML"

  class Niwings
    attr_accessor :username, :password, :timezone, :country, :vin
    attr_accessor :customSessionID, :initialAppString, :basePRM, :dcmID

    def initialize(attributes = {})
      @country = COUNTRY_USA
      @username = attributes.fetch(:username, nil)
      @password = attributes.fetch(:password, nil)
      @timezone = attributes.fetch(:timezone, "America/New_York")
      @vin = attributes.fetch(:vin, nil)
      @initialAppString = "geORNtsZe5I4lRGjG9GZiA"
      @dcmID = nil
      @basePRM = nil
      @customSessionID = nil
    end

    def hello()
      login()
    end

    private
    def login()
      resultPRM = post('InitialApp.php')
      pp resultPRM
      if resultPRM == nil or resultPRM.fetch("status").to_i != 200
        puts "Failed login!"
        return false
      end
      @basePRM = resultPRM.fetch("baseprm")
      crypted = Base64.encode64(Blowfish.encrypt(@basePRM, @password))
      decrypted = Blowfish.decrypt(@basePRM, Base64.decode64(crypted))

      #puts "'#{@password}' vs '#{decrypted}'"

      loginRequest = {"UserId": @username, "Password": crypted}
      resultLogin = post('UserLoginRequest.php', loginRequest)
      pp resultLogin
    end

    def get(endpoint)
      uri = URI.parse("#{BASE_URL}/#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      JSON.parse(response.body)
    end

    def post(endpoint, data = {})
      puts "POST to #{BASE_URL}/#{endpoint}"
      uri = URI.parse("#{BASE_URL}/#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(uri.request_uri)
      postData = {
        "RegionCode": self.country,
        "lg": "en-US",
        "initial_app_strings": self.initialAppString,
        "tz": self.timezone.upcase
      }
      postData.merge!({"VIN": self.vin}) if self.vin != nil
      postData.merge!({"DCMID": self.dcmID}) if self.dcmID != nil
      postData.merge!({"custom_sessionid": self.customSessionID}) if self.customSessionID != nil
      postData.merge!(data)

      #http.set_debug_output($stdout)

      request.set_form_data(postData)
      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end
