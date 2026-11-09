# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::S3UploadService, type: :service do
  describe '.call' do
    it 'stores the data as an Active Storage blob' do
      expect do
        described_class.call(data: 'hello', filename: 'note.txt', content_type: 'text/plain')
      end.to change(ActiveStorage::Blob, :count).by(1)
    end

    it 'returns a created result with the blob, key and url' do
      result = described_class.call(data: 'hello', filename: 'note.txt', content_type: 'text/plain')

      expect(result.success?).to be true
      expect(result.status).to eq(:created)
      expect(result.data[:blob]).to be_a(ActiveStorage::Blob)
      expect(result.data[:key]).to be_present
      expect(result.data[:url]).to be_present
    end

    it 'preserves the filename and content type' do
      blob = described_class.call(data: '%PDF-1.4', filename: 'fv.pdf', content_type: 'application/pdf').data[:blob]

      expect(blob.filename.to_s).to eq('fv.pdf')
      expect(blob.content_type).to eq('application/pdf')
    end

    it 'attaches the blob to a uuid-keyed record when asked' do
      photo = ProductPhoto.create!

      described_class.call(data: 'png-bytes', filename: 'photo.png', content_type: 'image/png',
                           attach_to: photo, as: :image)

      expect(photo.reload.image).to be_attached
    end

    it 'returns unprocessable_content without data' do
      result = described_class.call(data: '', filename: 'note.txt')

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
    end

    it 'returns unprocessable_content without a filename' do
      expect(described_class.call(data: 'hello', filename: '').status).to eq(:unprocessable_content)
    end
  end
end
