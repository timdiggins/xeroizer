Xeroizer API Library
====================

**Homepage**: 		[http://waynerobinson.github.com/xeroizer](http://waynerobinson.github.com/xeroizer)

**Git**: 					[git://github.com/waynerobinson/xeroizer.git](git://github.com/waynerobinson/xeroizer.git)

**Github**: 			[https://github.com/waynerobinson/xeroizer](https://github.com/waynerobinson/xeroizer)

**Author**: 			Wayne Robinson [http://www.wayne-robinson.com](http://www.wayne-robinson.com)

**Contributors**: See Contributors section below

**Copyright**:    2007-2013

**License**:      MIT License


Introduction
------------

This library is designed to help ruby/rails based applications communicate with the publicly available API for Xero.

If you are unfamiliar with the Xero API, you should first read the documentation located at http://developer.xero.com.

Installation
------------

	gem install xeroizer

Basic Usage
-----------

```ruby
require 'rubygems'
require 'xeroizer'

# Create client (used to communicate with the API).
client = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID, YOUR_OAUTH2_CLIENT_SECRET)

# Retrieve list of contacts (note: all communication must be made through the client).
contacts = client.Contact.all(:order => 'Name')
```

Authentication
--------------

#### Example Rails Controller

```ruby
class XeroSessionController < ApplicationController

	before_filter :get_xero_client

	public

		def new
			url = @xero_client.authorize_url(
				# The URL's domain must match that listed for your application
				# otherwise the user will see an invalid redirect_uri error
				redirect_uri: YOUR_CALLBACK_URL,
				# space separated, see all scopes at https://developer.xero.com/documentation/oauth2/scopes.
				# note that `offline_access` is required to get a refresh token, otherwise the access only lasts for 30 mins and cannot be refreshed.
				scope: "accounting.settings.read offline_access"
			)

			redirect_to url
		end

		def create
			token = @xero_client.authorize_from_code(
				params[:code],
				redirect_uri: YOUR_CALLBACK_URL
			)

			connections = @xero_client.current_connections

			session[:xero_auth] = {
				:access_token => token[:access_token],
				:refresh_token => token[:refresh_token],
				:tenant_id => connections[1][:tenant_id]
			}

		end

		def destroy
			session.data.delete(:xero_auth)
		end

	private

		def get_xero_client
			@xero_client = Xeroizer::OAuth2Application.new(
				YOUR_OAUTH2_CLIENT_ID,
				YOUR_OAUTH2_CLIENT_SECRET,
			)

			# Add AccessToken if authorised previously.
			if session[:xero_auth]
				@xero_client.tenant_id = session[:xero_auth][:tenant_id]

				@xero_client.authorize_from_access(session[:xero_auth][:acesss_token])
			end
		end
end
```

### OAuth2 Applications

For more details, checkout Xero's [documentation](https://developer.xero.com/documentation/oauth2/auth-flow)

1. Generate the authorization url and redirect the user to authenticate
```ruby
client = Xeroizer::OAuth2Application.new(
	YOUR_OAUTH2_CLIENT_ID,
	YOUR_OAUTH2_CLIENT_SECRET,
)
url = client.authorize_url(
	# The URL's domain must match that listed for your application
	# otherwise the user will see an invalid redirect_uri error
	redirect_uri: YOUR_CALLBACK_URL,
	# space separated, see all scopes at https://developer.xero.com/documentation/oauth2/scopes.
	# note that `offline_access` is required to get a refresh token, otherwise the access only lasts for 30 mins and cannot be refreshed.
	scope: "accounting.settings.read offline_access"
)

# Rails as an example
redirect_to url
```

2. In the callback route, use the provided code to retrieve an access token.

```ruby
token = client.authorize_from_code(
	params[:code],
	redirect_uri: YOUR_CALLBACK_URL
)
token.to_hash
# {
#   "token_type"=>"Bearer",
#   "scope"=>"accounting.transactions.read accounting.settings.read",
#   :access_token=>"...",
#   :refresh_token=>nil,
#   :expires_at=>1615220292
# }

# Save the access_token, refresh_token...
```

3. Retrieve the tenant ids.
```ruby
connections = client.current_connections
# returns Xeroizer::Connection instances

# Save the tenant ids

```

4. Use access token and tenant ids to retrieve data.
```ruby
client = Xeroizer::OAuth2Application.new(
	YOUR_OAUTH2_CLIENT_ID,
	YOUR_OAUTH2_CLIENT_SECRET,
	access_token: access_token,
	tenant_id: tenant_id
)
# OR
client = Xeroizer::OAuth2Application.new(
	YOUR_OAUTH2_CLIENT_ID,
	YOUR_OAUTH2_CLIENT_SECRET,
	tenant_id: tenant_id
).authorize_from_access(access_token)

# use the client
client.Organisation.first
```

#### AccessToken Renewal
Renewal of an access token requires the refresh token generated for this organisation. To renew:

```ruby
client = Xeroizer::OAuth2Application.new(
	YOUR_OAUTH2_CLIENT_ID,
	YOUR_OAUTH2_CLIENT_SECRET,
	access_token: access_token,
	refresh_token: refresh_token,
	tenant_id: tenant_id
)

client.renew_access_token
```
If you lose these details at any stage you can always reauthorise by redirecting the user back to the Xero OAuth gateway.

#### Custom Connections
Custom Connections are a paid-for option for private M2M applications. The generated token expires and needs recreating if expired. 

```ruby
client = Xeroizer::OAuth2Application.new(
	YOUR_OAUTH2_CLIENT_ID,
	YOUR_OAUTH2_CLIENT_SECRET
)

token = client.authorize_from_client_credentials
```
You can check the status of the token with the `expires?` and `expired?` methods.


Retrieving Data
---------------

Each of the below record types is implemented within this library. To allow for multiple access tokens to be used at the same
time in a single application, the model classes are accessed from the instance of OAuth2Application. All class-level operations occur on this singleton. For example:

```ruby
xero = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID, YOUR_OAUTH2_CLIENT_SECRET, tenant_id: tenant_id)
xero.authorize_from_access(session[:xero_auth][:access_token])

contacts = xero.Contact.all(:order => 'Name')

new_contact = xero.Contact.build(:name => 'ABC Development')
saved = new_contact.save
```

### \#all([options])

Retrieves list of all records with matching options.

**Note:** Some records (Invoice, CreditNote) only return summary information for the contact and no line items
when returning them this list operation. This library takes care of automatically retrieving the
contact and line items from Xero on first access however, this first access has a large performance penalty
and will count as an extra query towards your 5,000/day and 60/minute request per organisation limit.

Valid options are:

> **:modified\_since**

> Records modified after this `Time` (must be specified in UTC).

> **:order**

> Field to order by. Should be formatted as Xero-based field (e.g. 'Name', 'ContactID', etc)

> **:status**

> Status field for PurchaseOrder. Should be a valid Xero purchase order status.

> **:date_from**

> DateFrom field for PurchaseOrder. Should be in YYYY-MM-DD format.

> **:date_to**

> DateTo field for PurchaseOrder. Should be in YYYY-MM-DD format.

> **:where**

> __See *Where Filters* section below.__

### \#first([options])

This is a shortcut method for `all` and actually runs all however, this method only returns the
first entry returned by all and never an array.

### \#find(id)

Looks up a single record matching `id`. This ID can either be the internal GUID Xero uses for the record
or, in the case of Invoice, CreditNote and Contact records, your own custom reference number used when
creating these records.

### Where filters

#### Hash

You can specify find filters by providing the :where option with a hash. For example:

```ruby
invoices = Xero.Invoice.all(:where => {:type => 'ACCREC', :amount_due_is_not => 0})
```

will automatically create the Xero string:

	Type=="ACCREC"&&AmountDue<>0

The default method for filtering is the equality '==' operator however, these can be overridden
by modifying the postfix of the attribute name (as you can see for the :amount\_due field above).

	\{attribute_name}_is_not will use '<>'
	\{attribute_name}_is_greater_than will use '>'
	\{attribute_name}_is_greater_than_or_equal_to will use '>='
	\{attribute_name}_is_less_than will use '<'
	\{attribute_name}_is_less_than_or_equal_to will use '<='

	The default is '=='

**Note:** Currently, the hash-conversion library only allows for AND-based criteria and doesn't
take into account associations. For these, please use the custom filter method below.

#### Custom Xero-formatted string

Xero allows advanced custom filters to be added to a request. The where parameter can reference any XML element
in the resulting response, including all nested XML elements.

**Example 1: Retrieve all invoices for a specific contact ID:**

		invoices = xero.Invoice.all(:where => 'Contact.ContactID.ToString()=="cd09aa49-134d-40fb-a52b-b63c6a91d712"')

**Example 2: Retrieve all unpaid ACCREC Invoices against a particular Contact Name:**

		invoices = xero.Invoice.all(:where => 'Contact.Name=="Basket Case" && Type=="ACCREC" && AmountDue<>0')

**Example 3: Retrieve all Invoices PAID between certain dates**

		invoices = xero.Invoice.all(:where => 'FullyPaidOnDate>=DateTime.Parse("2010-01-01T00:00:00")&&FullyPaidOnDate<=DateTime.Parse("2010-01-08T00:00:00")')

**Example 4: Retrieve all Invoices using Paging (batches of 100)**

		invoices = xero.Invoice.find_in_batches({page_number: 1}) do |invoice_batch|
		  invoice_batch.each do |invoice|
		    ...
		  end
		end

**Example 5: Retrieve all Bank Accounts:**

		accounts = xero.Account.all(:where => 'Type=="BANK"')

**Example 6: Retrieve all DELETED or VOIDED Invoices:**

		invoices = xero.Invoice.all(:where => 'Status=="VOIDED" OR Status=="DELETED"')

**Example 7: Retrieve all contacts with specific text in the contact name:**

		contacts = xero.Contact.all(:where => 'Name.Contains("Peter")')
		contacts = xero.Contact.all(:where => 'Name.StartsWith("Pet")')
		contacts = xero.Contact.all(:where => 'Name.EndsWith("er")')

Associations
------------

Records may be associated with each other via two different methods, `has_many` and `belongs_to`.

**has\_many example:**

```ruby
invoice = xero.Invoice.find('cd09aa49-134d-40fb-a52b-b63c6a91d712')
invoice.line_items.each do | line_item |
	puts "Line Description: #{line_item.description}"
end
```

**belongs\_to example:**

```ruby
invoice = xero.Invoice.find('cd09aa49-134d-40fb-a52b-b63c6a91d712')
puts "Invoice Contact Name: #{invoice.contact.name}"
```

Attachments
------------
Files or raw data can be attached to record types
**attach\_data examples:**
```ruby
invoice = xero.Invoice.find('cd09aa49-134d-40fb-a52b-b63c6a91d712')
invoice.attach_data("example.txt", "This is raw data", "txt")
```

```ruby
attach_data('cd09aa49-134d-40fb-a52b-b63c6a91d712', "example.txt", "This is raw data", "txt")
```

**attach\_file examples:**
```ruby
invoice = xero.Invoice.find('cd09aa49-134d-40fb-a52b-b63c6a91d712')
invoice.attach_file("example.png", "/path/to/image.png", "image/png")
```

```ruby
attach_file('cd09aa49-134d-40fb-a52b-b63c6a91d712', "example.png", "/path/to/image.png", "image/png")
```

**include with online invoice**
To include an attachment with an invoice set include_online parameter to true within the options hash
```ruby
invoice = xero.Invoice.find('cd09aa49-134d-40fb-a52b-b63c6a91d712')
invoice.attach_file("example.png", "/path/to/image.png", "image/png", { include_online: true })
```

Creating/Updating Data
----------------------

### Creating

New records can be created like:

```ruby
contact = xero.Contact.build(:name => 'Contact Name')
contact.first_name = 'Joe'
contact.last_name = 'Bloggs'
contact.add_address(:type => 'STREET', :line1 => '12 Testing Lane', :city => 'Brisbane')
contact.add_phone(:type => 'DEFAULT', :area_code => '07', :number => '3033 1234')
contact.add_phone(:type => 'MOBILE', :number => '0412 123 456')
contact.save
```

To add to a `has_many` association use the `add_{association}` method. For example:

```ruby
contact.add_address(:type => 'STREET', :line1 => '12 Testing Lane', :city => 'Brisbane')
```

To add to a `belongs_to` association use the `build_{association}` method. For example:

```ruby
invoice.build_contact(:name => 'ABC Company')
```

### Updating

If the primary GUID for the record is present, the library will attempt to update the record instead of
creating it. It is important that this record is downloaded from the Xero API first before attempting
an update. For example:

```ruby
contact = xero.Contact.find("cd09aa49-134d-40fb-a52b-b63c6a91d712")
contact.name = "Another Name Change"
contact.save
```

Have a look at the models in `lib/xeroizer/models/` to see the valid attributes, associations and
minimum validation requirements for each of the record types.

Some Xero endpoints, such as Payment, will only accept specific attributes for updates. Because the library does not have this knowledge encoded (and doesn't do dirty tracking of attributes), it's necessary to construct new objects instead of using the ones retrieved from Xero:

```ruby
delete_payment = gateway.Payment.build(id: payment.id, status: 'DELETED')
delete_payment.save
```

### Bulk Creates & Updates

Xero has a hard daily limit on the number of API requests you can make (currently 5,000 requests
per account per day). To save on requests, you can batch creates and updates into a single PUT or
POST call, like so:

```ruby
contact1 = xero.Contact.create(some_attributes)
xero.Contact.batch_save do
  contact1.email_address = "foo@bar.com"
  contact2 = xero.Contact.build(some_other_attributes)
  contact3 = xero.Contact.build(some_more_attributes)
end
```

`batch_save` will issue one PUT request for every 2,000 unsaved records built within its block, and one
POST request for every 2,000 existing records that have been altered within its block. If any of the
unsaved records aren't valid, it'll return `false` before sending anything across the wire;
otherwise, it returns `true`. `batch_save` takes one optional argument: the number of records to
create/update per request. (Defaults to 2,000.)

If you'd rather build and send the records manually, there's a `save_records` method:
```ruby
contact1 = xero.Contact.build(some_attributes)
contact2 = xero.Contact.build(some_other_attributes)
contact3 = xero.Contact.build(some_more_attributes)
xero.Contact.save_records([contact1, contact2, contact3])
```
It has the same return values as `batch_save`.

### Errors

If a record doesn't match its internal validation requirements, the `#save` method will return
`false` and the `#errors` attribute will be populated with what went wrong.

For example:

```ruby
contact = xero.Contact.build
saved = contact.save

# contact.errors will contain [[:name, "can't be blank"]]
```

\#errors\_for(:attribute\_name) is a helper method to return just the errors associated with
that attribute. For example:

```ruby
contact.errors_for(:name) # will contain ["can't be blank"]
```

If something goes really wrong and the particular validation isn't handled by the internal
validators then the library may raise a `Xeroizer::ApiException`.

Example Use Cases
-------

Creating & Paying an invoice:

```ruby
contact = xero.Contact.first

# Build the Invoice, add a LineItem and save it
invoice = xero.Invoice.build(:type => "ACCREC", :contact => contact, :date => DateTime.new(2017,10,19), :due_date => DateTime.new(2017,11,19))

invoice.add_line_item(:description => 'test', :unit_amount => '200.00', :quantity => '1', :account_code => '200')

invoice.save

# An invoice created without a status will default to 'DRAFT'
invoice.approved?

# Payments can only be created against 'AUTHORISED' invoices
invoice.approve!

# Find the first bank account
bank_account = xero.Account.first(:where => {:type => 'BANK'})

# Create & save the payment
payment = xero.Payment.build(:invoice => invoice, :account => bank_account, :amount => '220.00')
payment.save

# Reload the invoice from the Xero API
invoice = xero.Invoice.find(invoice.id)

# Invoice status is now "PAID" & Payment details have been returned as well
invoice.status
invoice.payments.first
invoice.payments.first.date
```

Reports
-------

All Xero reports except GST report can be accessed through Xeroizer.

Currently, only generic report access functionality exists. This will be extended
to provide a more report-specific version of the data in the future (public submissions
are welcome).

Reports are accessed like the following example:

```ruby
trial_balance = xero.TrialBalance.get(:date => DateTime.new(2011,3,21))

profit_and_loss = xero.ProfitAndLoss.get(fromDate: Date.new(2019,4,1), toDate: Date.new(2019,5,1))

# Array containing report headings.
trial_balance.header.cells.map { | cell | cell.value }

# Report rows by section
trial_balance.sections.each do | section |
	puts "Section Title: #{section.title}"
	section.rows.each do | row |
		puts "\t#{row.cells.map { | cell | cell.value }.join("\t")}"
	end
end

# Summary row (if only one on the report)
trial_balance.summary.cells.map { | cell | cell.value }

# All report rows (including HeaderRow, SectionRow, Row and SummaryRow)
trial_balance.rows.each do | row |
	case row
		when Xeroizer::Report::HeaderRow
			# do something with header

		when Xeroizer::Report::SectionRow
			# do something with section, will need to step into the rows for this section

		when Xeroizer::Report::Row
			# do something for standard report rows

		when Xeroizer::Report::SummaryRow
			# do something for summary rows

	end
end
```

Xero API Rate Limits
--------------------

The Xero API imposes the following limits on calls per organisation:

* A limit of 60 API calls in any 60 second period
* A limit of 5000 API calls in any 24 hour period

By default, the library will raise a `Xeroizer::OAuth::RateLimitExceeded`
exception when one of these limits is exceeded.

If required, the library can handle these exceptions internally by sleeping
for a configurable number of seconds and then repeating the last request.
You can set this option when initializing an application:

```ruby
# Sleep for 2 seconds every time the rate limit is exceeded.
client = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID,
                                         YOUR_OAUTH2_CLIENT_SECRET,
                                         :rate_limit_sleep => 2)
```

Xero API Nonce Used
-------------------

The Xero API seems to reject requests due to conflicts on occasion.

By default, the library will raise a `Xeroizer::OAuth::NonceUsed`
exception when one of these limits is exceeded.

If required, the library can handle these exceptions internally by sleeping 1 second and then repeating the last request.
You can set this option when initializing an application:

```ruby
# Sleep for 1 second and retry up to 3 times when Xero claims the nonce was used.
client = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID,
                                         YOUR_OAUTH2_CLIENT_SECRET,
                                         :nonce_used_max_attempts => 3)
```


Logging
---------------

You can add an optional parameter to the Xeroizer Application initialization, to pass a logger object that will need to respond_to :info. For example, in a rails app:

```ruby
XeroLogger = Logger.new('log/xero.log', 'weekly')
client = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID,
                                         YOUR_OAUTH2_CLIENT_SECRET,
                                         :logger => XeroLogger)
```

HTTP Callbacks
--------------------

You can provide "before", "after" and "around" callbacks which will be invoked every
time Xeroizer makes an HTTP request, which is potentially useful for both
throttling and logging:

```ruby
Xeroizer::OAuth2Application.new(
  credentials[:key], credentials[:secret],
  before_request: ->(request) { puts "Hitting this URL: #{request.url}" },
  after_request: ->(request, response) { puts "Got this response: #{response.code}" },
  around_request: -> (request, &block)  { puts "About to send request"; block.call; puts "After request"}
)
```

The `request` parameter is a custom Struct with `url`, `headers`, `body`,
and `params` methods. The `response` parameter is a Net::HTTPResponse object.


Unit Price Precision
--------------------

By default, the API accepts unit prices (UnitAmount) to two decimals places. If you require greater precision, you can opt-in to 4 decimal places by setting an optional parameter when initializing an application:


```ruby
client = Xeroizer::OAuth2Application.new(YOUR_OAUTH2_CLIENT_ID,
                                         YOUR_OAUTH2_CLIENT_SECRET,
                                         :unitdp => 4)
```

This option adds the unitdp=4 query string parameter to all requests for models with line items - invoices, credit notes, bank transactions and receipts.

Tests
-----

OAuth2 Tests

The tests within the repository can be run by setting up a [OAuth2 App](https://developer.xero.com/documentation/guides/oauth2/auth-flow/).  You can create a Private App in the [developer portal](https://developer.xero.com/myapps/), it's suggested that you create it against the [Demo Company (AU)](https://developer.xero.com/documentation/getting-started/development-accounts). Demo Company expires after 28 days, so you will need to reset it and re-connect to it if your Demo Company has expired. Make sure you create the Demo Company in Australia region.

```
export XERO_CLIENT_ID="asd"
export XERO_CLIENT_SECRET="asdfg"
export XERO_ACCESS_TOKEN="sadfsdf"
export XERO_TENANT_ID="asdfasdfasdfasd"

rake test
```

### Contributors
Xeroizer was inspired by the https://github.com/tlconnor/xero_gateway gem created by Tim Connor
and Nik Wakelin and portions of the networking and authentication code are based completely off
this project. Copyright for these components remains held in the name of Tim Connor.
