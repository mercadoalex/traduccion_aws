import boto3  # AWS SDK for Python. It enables Python developers to create, configure, and manage AWS services.
import argparse  # standard library module in Python for parsing command-line arguments
import os  # standard library module for interacting with the operating system

# Initialize the boto3 client for Translate
translate = boto3.client('translate')

def translate_text(text, source_language, target_language):
    result = translate.translate_text(
        Text=text,
        SourceLanguageCode=source_language,
        TargetLanguageCode=target_language
    )
    return result['TranslatedText']

def split_text(text, max_size=10000):
    """Splits the text into chunks of max_size bytes."""
    chunks = []
    while len(text.encode('utf-8')) > max_size:
        split_index = max_size
        while len(text[:split_index].encode('utf-8')) > max_size:
            split_index -= 1
        chunks.append(text[:split_index])
        text = text[split_index:]
    chunks.append(text)
    return chunks

def main():
    parser = argparse.ArgumentParser(description='Translate a document.')
    parser.add_argument('source_language', type=str, help='Source language code')
    parser.add_argument('target_language', type=str, help='Target language code')
    parser.add_argument('file_path', type=str, help='Path to the file to translate')
    args = parser.parse_args()

    # Read the content of the file
    with open(args.file_path, 'r', encoding='utf-8') as file:
        text = file.read()

    # Split the text into chunks
    text_chunks = split_text(text)

    # Translate each chunk and concatenate the results
    translated_text = ""
    for chunk in text_chunks:
        translated_text += translate_text(chunk, args.source_language, args.target_language)

    # Ensure the output directory exists
    output_dir = os.path.dirname(f"translated-{args.file_path}")
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Write the translated text to a new file
    output_file_path = f"translated-{args.file_path}"
    with open(output_file_path, 'w', encoding='utf-8') as output_file:
        output_file.write(translated_text)

    print(f"Translated text written to {output_file_path}")

if __name__ == "__main__":
    main()