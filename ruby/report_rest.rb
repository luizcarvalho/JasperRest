#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "net/http"
require "rexml/document"

REPORT_NAME = 'StandardChartsReport'
REPORT_GROUP = "samples"
SERVER_ROOT = "127.0.0.1" #MUDE PARA O ENDERECO DE SEU SERVIDOR 
SERVER_PORT = 8080
SERVER_USER = "jasperadmin"
SERVER_PASSWORD = "jasperadmin"
FORMAT = "PDF"
FILE_NAME = "report.pdf"


REPORT_PATH = "http://#{SERVER_ROOT}:#{SERVER_PORT}/jasperserver/rest/report"

def to_ms(time)
	start = Time.new(1970,1,1)
	((time.to_f - start.to_f) * 1000.0).to_i
end

#parametros sendo passados somente como exemplo
PARAMS = {:criacao_inicio=>to_ms(Time.new(2011,01,01)),:criacao_final=>to_ms(Time.new(2014,01,01))}


def build_xml_request
	url_string = "/reports/#{REPORT_GROUP}/#{REPORT_NAME}"
	request_body = "<resourceDescriptor name='#{REPORT_NAME}' wsType='reportUnit' uriString='#{url_string}' isNew='false'><label>null</label>"
	puts "CRIANDO XML PARA: #{url_string} "
	PARAMS.each do|k,v| 
		request_body += "<parameter name='#{k}'>#{v.to_s}</parameter>"
		puts "PARAMETROS: #{k}=#{v.to_s}; "
	end
	request_body += "</resourceDescriptor>"
end

def get_uuid_and_cookie

	body = ""
	cookie = ""
	puts "FULL URL: #{"#{REPORT_PATH}/reports/#{REPORT_GROUP}/#{REPORT_NAME}"}"
	uri = URI.parse("#{REPORT_PATH}/reports/#{REPORT_GROUP}/#{REPORT_NAME}")
	http = Net::HTTP.new(uri.host, uri.port)
	http.start do |http|
		req = Net::HTTP::Put.new(uri.path + "?RUN_OUTPUT_FORMAT=#{FORMAT}")
		puts "ACESSANDO: #{uri.path}?RUN_OUTPUT_FORMAT=#{FORMAT}"
		req.basic_auth(SERVER_USER, SERVER_PASSWORD)
		req.body = build_xml_request
		resp = http.request(req)
		body = resp.body
		puts "COOKIE RECEBIDO: #{resp['Set-Cookie']}"		
		cookie = resp['Set-Cookie']
	end

	xml = REXML::Document.new(body)
	puts "\n\n XML \n #{xml} \n\n"
	uuid_xml = xml.elements["report/uuid"]
	
	if uuid_xml
		uuid = uuid_xml.text
		puts "UUID RECEBIDO: #{uuid}" 
		return uuid,cookie
	else
		puts "PROBLEMA AO RECEBER UUID. RESPOSTA: #{uuid_xml}" 
		return false,false
	end
end

def get_file
	body_get = nil
	uuid,cookie = get_uuid_and_cookie
	if uuid
		uri_get = URI.parse("#{REPORT_PATH}/#{uuid}")
		puts "URL DO RELATORIO: #{uri_get}"
		http_get = Net::HTTP.new(uri_get.host, uri_get.port)

		http_get.start do |http|
			req = Net::HTTP::Get.new(uri_get.path + "?file=report")		
			puts "REQ: #{req.path}"
			req.basic_auth(SERVER_USER, SERVER_PASSWORD)
			req['cookie'] = cookie
			resp = http.request(req)
			body_get = resp.body		
		end
	end
	body_get
end


file = get_file
if file 
	#puts file
	f = File.new(FILE_NAME, 'wb')
	f.write(file)
	f.close
else
	puts "Não foi possível criar o relatório"
end	
