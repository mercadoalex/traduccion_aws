import boto3 # type: ignore #AWS SDK for Python. It enables Python developers to create, configure, and manage AWS services.
import argparse # standard library module in Python for parsing command-line arguments

# Set up argument parser
parser = argparse.ArgumentParser()
parser.add_argument("SourceLanguageCode") # Source language code argument
parser.add_argument("TargetLanguageCode") # Target language code argument
parser.add_argument("SourceFile")  # Source file argument
args = parser.parse_args()

# Initialize AWS Translate client
translate = boto3.client('translate')

localFile = args.SourceFile
file = open(localFile, "rb")  #opens the file specified by localFile in binary read mode ("rb")
data = file.read()
file.close()

# Read the source file
result = translate.translate_document(
    Document={
            "Content": data,
            "ContentType": "text/html"
        },
    SourceLanguageCode=args.SourceLanguageCode,
    TargetLanguageCode=args.TargetLanguageCode
)
# Save the translated document if translation is successful
if "TranslatedDocument" in result:
    fileName = localFile.split("/")[-1]
    tmpfile = f"{args.TargetLanguageCode}-{fileName}"
    with open(tmpfile,  'w') as f:
        f.write(result["TranslatedDocument"]["Content"].decode('utf-8'))
        
    print("Translated document ", tmpfile)