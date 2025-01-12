import boto3  # AWS SDK for Python. It enables Python developers to create, configure, and manage AWS services.
import argparse  # standard library module in Python for parsing command-line arguments

# Initialize the boto3 client for Translate
translate = boto3.client('translate')

def translate_text(text, source_language, target_language):
    result = translate.translate_text(
        Text=text,
        SourceLanguageCode=source_language,
        TargetLanguageCode=target_language
    )
    return result['TranslatedText']

def main():
    parser = argparse.ArgumentParser(description='Translate a document.')
    parser.add_argument('source_language', type=str, help='Source language code')
    parser.add_argument('target_language', type=str, help='Target language code')
    parser.add_argument('file_path', type=str, help='Path to the file to translate')
    args = parser.parse_args()

    # Read the content of the file
    with open(args.file_path, 'r', encoding='utf-8') as file:
        text = file.read()

    # Translate the text
    translated_text = translate_text(text, args.source_language, args.target_language)

    # Write the translated text to a new file
    output_file_path = f"translated-{args.file_path}"
    with open(output_file_path, 'w', encoding='utf-8') as output_file:
        output_file.write(translated_text)

    print(f"Translated text written to {output_file_path}")

if __name__ == "__main__":
    main()