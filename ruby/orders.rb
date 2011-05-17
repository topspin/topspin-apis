#!/usr/bin/env ruby
=begin
Copyright (c) 2009, Topspin Media, Inc
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, 
   this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
  * Neither the name of the Topspin Media, Inc nor the names of its contributors
   may be used to endorse or promote products derived from this software 
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

require 'rubygems'
require 'net/http'
require 'ostruct'
require 'json'
require 'optparse'
require 'pp'

class OrdersClient
  
  FILTER_OPTIONS = [
    'contains_merch' ,
    'shipped'        ,
    'not_shipped'    ,
    'past_due'       ,
    'pending'        ,
    'acknowledged'   ,
    'all'            ,
  ].freeze

  COMMANDS = [:index,:update,:batch_update,:sku_index,:sku_update,:sku_add,:sku_remove].freeze
  
  attr_reader(:options)
  def initialize options
    @options = options
  end

  def run
    debug "command: #{options.command}"
    __send__ "cmd_#{options.command}"
  end

  def cmd_index
    search = { 
      :filter    => options.filter    ,
      :page      => options.page      ,
      :page_size => options.page_size , 
      :sortcol   => options.sortcol   , 
      :sortdir   => options.sortdir   , 
    }

    if options.term_name && options.term_value
      search[:terms] = [ [ options.term_name , options.term_value ] ]
    end

    search = search.to_json
    
    orders = post_form("/api/v1/order", "search" => search)
    pp orders
    return orders
  end

  def cmd_batch_update
    search = { :filter => options.filter }.to_json
    params = {
      :shipped         => options.shipped       ,
      :shipping_date   => options.shipping_date ,
      :tracking_code   => options.tracking_code ,
      :tracking_type   => options.tracking_type ,
      :search          => search                ,
    }
    pp post_form("/api/v1/order/batch_update",params)
  end

  def cmd_update
    email_param = options.email ? "?email_on_update=true" : "?email_on_update=false"
    params = {
      :orders => [{
        :id    =>  options.order_id,
        :items => [{
            :id             => options.status_id     ,
            :shipping_date  => options.shipping_date ,
            :shipped        => options.shipped       ,
            :tracking_code  => options.tracking_code ,
            :tracking_type  => options.tracking_type ,
        }]
      }]
    }.to_json
    pp post("/api/v1/order/update#{email_param}",params,"text/javascript")
  end

  def cmd_sku_index
    pp get("/api/v1/sku")
  end

  def cmd_sku_update
    params = {}
    params[:id]          = options.sku_id      unless options.sku_id.nil?
    params[:available]   = options.available   unless options.available.nil?
    params[:quantity]    = options.quantity    unless options.quantity.nil?
    params[:factory_sku] = options.factory_sku unless options.factory_sku.nil?
    params[:weight]      = options.weight      unless options.weight.nil?
    params[:weight_unit] = options.weight_unit unless options.weight_unit.nil?
    pp put_form("/api/v1/sku/update",params)
  end

  def cmd_sku_add
    params = {}
    params[:id]          = options.sku_id      unless options.sku_id.nil?
    params[:quantity]    = options.quantity    unless options.quantity.nil?
    pp put_form("/api/v1/sku/add",params)
  end

  def cmd_sku_remove
    params = {}
    params[:id]          = options.sku_id      unless options.sku_id.nil?
    params[:quantity]    = options.quantity    unless options.quantity.nil?
    pp put_form("/api/v1/sku/remove",params)
  end

  def get action, params = {}
    uri = request_uri(action)
    req = Net::HTTP::Get.new(uri.path)
    request uri, req
  end

  def post_form action, params = {}
    uri = request_uri(action)
    req = Net::HTTP::Post.new(action)
    req.set_form_data params
    request uri, req
  end
    
  def put_form action, params = {}
    uri = request_uri(action)
    req = Net::HTTP::Put.new(action)
    req.set_form_data params
    request uri, req
  end

  def post action, data=nil, content_type = nil
    uri              = request_uri(action)
    req              = Net::HTTP::Post.new(action)
    req.body         = data
    req.content_type = content_type if content_type
    request uri, req
  end

  def request uri, req
    req.basic_auth options.username, options.password
    http = Net::HTTP.new(uri.host, uri.port)
    http.set_debug_output($stderr) if options.debug
    res = http.start do |http|
      http.request req
    end
    res.error! unless res.is_a?(Net::HTTPSuccess)
    debug "response = #{res.body}"
    JSON.parse(res.body)
  end

  def request_uri path
    URI.join(options.url, path)
  end

  def debug str
    $stderr.puts(str) if options.debug
  end

  def self.parse args
    options           = OpenStruct.new
    options.url       = "http://app.topspin.net"
    options.debug     = false
    options.command   = :index
    options.debug     = false
    options.filter    = "contains_merch"
    options.page      = '1'
    options.page_size = 25
    options.sortcol   = 'order_id'
    options.sortdir   = 'desc'
    options.email     = false

    OptionParser.new do |opts|

      opts.on "-H HOST", "--host=HOST", "API Host (#{options.url})" do |x|
        options.url = x
      end

      opts.on "-u USERNAME","--username=USERNAME","Username" do |x|
        options.username = x
      end

      opts.on "-p PASSWORD", "--password=PASSWORD","Password" do |x|
        options.password = x
      end

      opts.on "-c COMMAND","--command=COMMAND",COMMANDS,"Command (#{options.command}) commands: #{COMMANDS.join(',')}" do |x|
        options.command = x
      end

      opts.on "-d DATE","--shipping-date=DATE","Shipping Date" do |x|
        options.shipping_date = x
      end

      opts.on "-o ORDER_ID","--order-id=ORDER_ID",Integer,"Order ID" do |x|
        options.order_id = x
      end

      opts.on "-S STATUS_ID","--status-id=STATUS_ID",Integer,"Status ID" do |x|
        options.status_id = x
      end

      opts.on "--[no-]shipped","Shipped?" do |x|
        options.shipped = x ? "shipped" : "pending"
      end

      opts.on "-C TRACK_CODE","--track-code=TRACK_CODE", "Delivery Tracking Code" do |x|
        options.tracking_code = x
      end

      opts.on "-T TRACK_TYPE","--track-type=TRACK_TYPE",["DHL","FEDEX","UPS","USPS","Other"],"Delivery Tracking Type" do |x|
        options.tracking_type = x
      end

      opts.on "--[no-]available","Sku available?" do |x|
        options.available = x
      end

      opts.on "--factory-sku=SKU","Factory Sku" do |x|
        options.factory_sku = x
      end

      opts.on "--weight=WEIGHT","Weight" do |x|
        options.weight = x
      end

      opts.on "--weight-unit=WEIGHT_UNIT",["lb","oz","kg","g"],"Weight Unit" do |x|
        options.weight_unit = x
      end

      opts.on "--sku-id=SKU_ID",Integer,"Sku ID" do |x|
        options.sku_id = x
      end

      opts.on "-q QUANTITY", "--quantity=QUANTITY",Integer,"Sku Quantity" do |x|
        options.quantity = x 
      end 

      opts.on "--[no-]debug","Debug (#{options.debug})" do |x|
        options.debug = x
      end

      opts.on "--[no-]email","Email (#{options.email})" do |x|
        options.email = x
      end

      opts.on "-f FILTER","--filter=FILTER",FILTER_OPTIONS,"Filter (#{options.filter})" do |x|
        options.filter = x
      end

      opts.on "--page=PAGE",Integer, "Page (#{options.page})" do |x|
        options.page = x
      end

      opts.on "--page-size=SIZE", Integer, "Page size (#{options.page_size})" do |x| 
        options.page_size = x
      end

      opts.on "--sortcol=SORTCOL","Sort Column (#{options.sortcol})" do |x|
        options.sortcol = x
      end

      opts.on "--sortdir=SORTDIR","Sort Direction (#{options.sortdir})" do |x|
        options.sortdir = x
      end

      opts.on "--term-name=NAME", "Search term name" do |x|
        options.term_name = x
      end

      opts.on "--term-value=VALUE", "Search term value" do |x| 
        options.term_value = x
      end

      opts.on_tail "-h", "--help", "Show this message" do
        puts opts
        exit
      end

    end.parse! args
    options
  end

  def self.run args
    new(parse(args)).run
  end
end

if $0 == __FILE__
  OrdersClient.run ARGV
end
