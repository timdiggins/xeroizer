# Copyright (c) 2008 Tim Connor <tlconnor@gmail.com>
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

module Xeroizer

  class XeroizerError < StandardError
    def validation_errors
      [message]
    end
  end

  class ApiException < XeroizerError
    
    attr_reader :type, :message, :xml, :parsed_xml, :request_body
    
    def initialize(type, message, xml, parsed_xml, request_body)
      @type         = type
      @message      = message
      @xml          = xml
      @parsed_xml   = parsed_xml
      @request_body = request_body
    end
    
    def message
      "#{@type}: #{@message} \n Generated by the following XML: \n #{@xml}"
    end

    def validation_errors
      errors = []
      @parsed_xml.xpath("//ValidationError").each do |err|
        errors << err.text.gsub(/^\s+/, '').gsub(/\s+$/, '')
      end
      errors
    rescue
      [message]
    end
    
  end
  
  class UnparseableResponse < XeroizerError
    
    def initialize(root_element_name)
      @root_element_name = root_element_name
    end
    
    def message
      "A root element of #{@root_element_name} was returned, and we don't understand that!"
    end
      
  end
  
  class ObjectNotFound < XeroizerError
    
    def initialize(api_endpoint)
      @api_endpoint = api_endpoint
    end
    
    def message
      "Couldn't find object for API Endpoint #{@api_endpoint}"
    end
    
  end
  
  class InvoiceNotFoundError < XeroizerError; end

  class CreditNoteNotFoundError < XeroizerError; end
  
  class MethodNotAllowed < XeroizerError
    
    def initialize(klass, method)
      @klass = klass
      @method = method
    end
    
    def message
      "Method #{@method} not allowed on #{@klass}"
    end
    
  end
  
  class RecordKeyMustBeDefined < XeroizerError
    
    def initialize(possible_keys)
      @possible_keys = possible_keys
    end
    
    def message
      "One of the keys #{@possible_keys.join(', ')} need to be defined to update the record."
    end
    
  end

  class RecordInvalid < XeroizerError; end

  class SettingTotalDirectlyNotSupported < XeroizerError
    
    def initialize(attribute_name)
      @attribute_name = attribute_name
    end
    
    def message
      "Can't set the total #{@attribute_name} directly as this is calculated automatically."
    end
    
  end

  class InvalidAttributeInWhere < XeroizerError
    
    def initialize(model_name, attribute_name)
      @model_name = model_name
      @attribute_name = attribute_name
    end
    
    def message
      "#{@attribute_name} is not an attribute of #{@model_name}."
    end
    
  end
  
  class AssociationTypeMismatch < XeroizerError
    
    def initialize(model_class, actual_class)
      @model_class = model_class
      @actual_class = actual_class
    end
  
    def message
      "#{@model_class} expected, got #{@actual_class}"
    end
    
  end

  class CannotChangeInvoiceStatus < XeroizerError

    def initialize(invoice, new_status)
      @invoice = invoice
      @new_status = new_status
    end

    def message
      case @new_status
        when 'DELETED', 'VOIDED'
          unless @invoice.payments.size == 0
            "There must be no payments in this invoice to change to '#{@new_status}'"
          end

      end
    end

  end

  class InvalidClientError < XeroizerError; end
  
end
