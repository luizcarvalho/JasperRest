#!/usr/bin/env python
# -*- coding: utf-8 -*-
from reports import RestReport,RestError
from datetime import datetime

params = {"criacao_inicio":datetime(2011,1,1),"criacao_final":datetime(2014,1,1)}

rest_conn = RestReport("samples","StandardChartsReport")
rest_conn.set_params(params)
report_data = rest_conn.generate_report()
if report_data:
  report = open("thereport.pdf",'wp')
  report.write(report_data)
  report.close
else:
  print "Não foi possível criar o relatório"
