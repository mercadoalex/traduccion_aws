import re  # Import the regular expression module

def handler(event, context):
    # Extract the request from the CloudFront event
    request = event['Records'][0]['cf']['request']
    
    # Get the 'accept-language' header from the request
    viewerCountry = request['headers'].get('accept-language')
    if viewerCountry:
        # Extract the country code from the 'accept-language' header
        countryCode = viewerCountry[0]['value']
        # Check if the country code starts with 'es' (for Spanish)
        if re.match(r'^es', countryCode):
            # Set the domain name to the Spanish assets bucket
            domainName = "my-spanish-assets-bucket.s3.us-east-1.amazonaws.com"
            request['origin']['s3']['domainName'] = domainName
            # Update the 'host' header to match the new domain name
            request['headers']['host'] = [{'key': 'host', 'value': domainName}]
    
    # Return the modified request
    return request