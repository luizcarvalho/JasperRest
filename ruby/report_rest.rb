#!/usr/bin/env ruby
# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'net/http'
require 'rexml/document'
require 'json'
require 'dotenv/load'

@report_name = 'StandardChartsReport'
@report_group = 'samples'
SERVER_ROOT = ENV['JASPER_SERVER'] # Your Jasper Server Address
SERVER_PORT = ENV['JASPER_PORT']
SERVER_USER = ENV['JASPER_USER']
SERVER_PASSWORD = ENV['JASPER_PASSWORD']
DEBUG = false
TIMEOUT = 3600 # seconds

class Jasper
  BASE_URL = 'http://%s:%s/jasperserver/rest/report' % [SERVER_ROOT, SERVER_PORT]
  TIME_ZONE_PARAMS = 'userTimezone=America/Araguaina'.freeze

  def initialize(report_group, report_name, params, format = 'pdf')
    @report_group = report_group
    @report_name = report_name
    @params = string_to_hash(params)
    @format = format
    @partial_url = '/reports/%s/%s' % [@report_group, @report_name, TIME_ZONE_PARAMS]
    @full_url = "#{BASE_URL}/#{@partial_url}"
  end

  def build_xml_request
    request_body = "<resourceDescriptor name='#{@report_name}' wsType='reportUnit' uriString='#{@partial_url}' isNew='false'><label>null</label>"
    @params.each do |k, v|
      request_body += "<parameter name='#{k}'>#{v}</parameter>"
    end
    request_body += '</resourceDescriptor>'
  end

  def get_uuid_and_cookie
    body = ''
    cookie = ''
    uri = URI.parse(@full_url)
    net_http = Net::HTTP.new(uri.host, uri.port)
    net_http.read_timeout = TIMEOUT
    net_http.start do |http|
      req = Net::HTTP::Put.new(uri.path + "?RUN_OUTPUT_FORMAT=#{@format}")
      req.basic_auth(SERVER_USER, SERVER_PASSWORD)
      req.body = build_xml_request
      resp = http.request(req)
      body = resp.body
      cookie = resp['Set-Cookie']
    end
    puts body

    xml = REXML::Document.new(body)
    uuid_xml = xml.elements['report/uuid']

    if uuid_xml
      uuid = uuid_xml.text
      return uuid, cookie
    else
      return false, false
    end
  end

  def get_file
    body_get = nil
    uuid, cookie = get_uuid_and_cookie
    req = nil
    if uuid
      uri_get = URI.parse("#{BASE_URL}/#{uuid}")
      http_get = Net::HTTP.new(uri_get.host, uri_get.port)
      http_get.read_timeout = TIMEOUT
      http_get.start do |http|
        req = Net::HTTP::Get.new(uri_get.path + '?file=report')
        req.basic_auth(SERVER_USER, SERVER_PASSWORD)
        req['cookie'] = cookie
        resp = http.request(req)
        body_get = resp.body
      end
    else
      raise JasperError, JasperError.request_error_message_for(@full_url)
    end
    body_get
  end

  private

  def to_ms(time)
    start = Time.new(1970, 1, 1)
    ((time.to_f - start.to_f) * 1000.0).to_i
  end

  def string_to_hash(string)
    if string.is_a? String
      JSON.parse(string)
    elsif string.is_a? Hash
      string
    else
      raise JasperError, "Os parametros devem ser String(JSON) ou Hash e são #{string.class}"
    end
  end
end

class JasperError < StandardError
  def self.request_error_message_for(url)
    "Erro ao conectar com Jasper, verifique se o servidor está ativo,
    se o relatório no Jasper está sendo gerado corretamente (diretamente na interface do Jasper) ou ainda
    se o endereço do relatório está correto: #{url}"
  end
end
