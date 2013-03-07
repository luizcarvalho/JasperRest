# -*- coding: utf-8 -*-
'''
 Python Rest Client for Jasper Report Server 
 Biblioteca para facilitar o processo de comunicação com servidor
 de relatório Jasper Report Server
'''
__author__      = "Luiz Carvalho"
__copyright__   = "Copyright 2013, Defensoria Pública do Estado do Tocantins"
__version__     = '1.0.1'

import urllib2
import base64
from urlparse import urlparse
import xml.etree.ElementTree    as ET
from datetime import datetime,date
import time



SERVER_ADDR= "127.0.0.1"
SERVER_PORT = 8080
USERNAME = "jasperadmin"
PASSWORD = "jasperadmin"
REPORT_URI = "http://%s:%s/jasperserver/rest/report/"%(SERVER_ADDR,SERVER_PORT)


class RestReport():
    '''
    RestReport é um cliente para acesso A API RESTful dos repositórios do Jasper Report Server
    Possibilitando de maneira simples a geração de relatórios presentes no servidor
    '''
    report_name= None
    report_path = None
    format = 'pdf'
    auth_token = None
    auth_cookie = None
    uuid = None
    params = {}



    def __init__(self,report_path,report_name,format='pdf'):
        '''
        PARAMS: 
            report_path:`string`
                ex: 'athenas','athenas/rh','athenas/edoc'
            report_name:`string`
                ex: 'protocolo','contracheque'
            format:`string` (optional)
                ex: 'pdf','csv','xml','xls'
        OBS: para passar os parâmetros para consulta utilize  o metodo +set_params(parametros)+       
        '''
        self.report_name = report_name
        self.report_path = report_path
        self.format = format

    def set_params(self,params):
        '''
        Inclui os parametros necessários para pesquisa no relatório
        PARAMS:
            params:`dict`
                ex: "criacao_inicio":`datetime`(2011,1,1),"criacao_final":`datetime`(2014,1,1),'protocolo':201302011234}
        '''

        if(type(params) == dict):
            for k,v in params.items():
                if isinstance(v,date):
                    self.params[k]= self.to_ms(v)
                else:
                    self.params[k]=v
        else:
            raise TypeError("Params is not Dict Type")


    def build_xml_request(self):
        '''
        Cria a estrutura XML para acesso e consulta no relatório
        RETURN: xml_request:`string`
        '''
        url_string = "/reports/"+self.report_path+"/"+self.report_name
        request_body = "<resourceDescriptor name='"+self.report_name+"' wsType='reportUnit' uriString='"+url_string+"' isNew='false'><label>null</label>"
        #print "CRIANDO XML PARA: "+url_string
        for k,v in self.params.items():
            request_body += "\n<parameter name='%s'>%s</parameter>\n"% (k, v)
            print "CHAVE=>",k,"VALOR=>",v
        request_body+="</resourceDescriptor>"
        return request_body



    def authenticator(self):
        '''
        Realiza a autenticação e preparação no servidor Jasper Report para que seja possível a geração do relatório.
        '''        
        handle = None
        body = ""        
        uri = REPORT_URI+"reports/"+self.report_path+"/"+self.report_name+"/?RUN_OUTPUT_FORMAT="+self.format
        req = urllib2.Request(uri)
        base64string = base64.encodestring('%s:%s' % (USERNAME, PASSWORD))[:-1]
        authheader =    "Basic %s" % base64string
        req.add_header("Authorization", authheader)
        req.get_method = lambda: 'PUT'
        
        req.data = self.build_xml_request()
        try:
                handle = urllib2.urlopen(req)
                self.auth_cookie =    handle.headers["Set-Cookie"]
                body = handle.read()
        except Exception, e:                
                raise RestError(e,"O Servidor não está respondendo ao endereço solicitado: "+uri)

        xml = ET.fromstring(body)    
        try:            
            uuid = xml.find('uuid').text            
        except Exception, e:            
            raise ValueError(e,"Identificador do Relatório Não Encontrado (UUID)")            
        self.uuid = uuid


    def generate_report(self):
        '''
        Gera o relatório no servidor retornando o conteúdo do relatório em dados
        RETURN: report_data:`string`
        '''
        body = None
        auth = self.authenticator()
        req = urllib2.Request(REPORT_URI+self.uuid+"?file=report")
        base64string = base64.encodestring('%s:%s' % (USERNAME, PASSWORD))[:-1]
        authheader =    "Basic %s" % base64string
        req.add_header("Authorization", authheader)
        req.add_header("Cookie", self.auth_cookie)
        req.get_method = lambda: 'GET'
        try:
            handle = urllib2.urlopen(req)
            report_data = handle.read()
        except Exception, e:            
            raise RestError(e,"Não foi possível obter o relatório do servidor: "+req.get_full_url())
                        
        return report_data

    def to_ms(self,final):
        '''
        Converte Datas para tempo em milissegundos
        PARAMS:
            a_time:`datetime`
        RETURN:
            time_in_ms:`int`    
        '''
        start = datetime.utcfromtimestamp(0) #1970,1,1        
        final_ms = time.mktime(final.timetuple())
        start_ms = time.mktime(start.timetuple())
        return int(final_ms-start_ms)*1000

class RestError(Exception):
    """Rest Report exception"""

    def __init__(self, reason, message=None):        
        self.reason = str(reason)
        self.full_message = str(message+"\n"+self.reason)
        #print "REST REPORT ERROR: "+self.reason

    def __str__(self):
        return self.full_message

