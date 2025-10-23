import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

class FaceEmbeddingService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  // Initialize the TFLite model
  static Future<bool> initialize() async {
    try {
      print('=== Initializing Face Embedding Service ===');

      // Check if model file exists in assets
      print('Loading model from assets...');

      try {
        // Try to load the model from assets
        _interpreter = await Interpreter.fromAsset('assets/models/output_model.tflite');
        print('Model loaded successfully from assets');
      } catch (e) {
        print('ERROR: Failed to load model from assets: $e');

        // Try alternative paths
        try {
          _interpreter = await Interpreter.fromAsset('models/output_model.tflite');
          print('Model loaded successfully from alternative path');
        } catch (e2) {
          print('ERROR: Failed to load model from alternative path: $e2');
          return false;
        }
      }

      // Check interpreter details
      if (_interpreter != null) {
        print('Model input details:');
        for (int i = 0; i < _interpreter!.getInputTensors().length; i++) {
          final tensor = _interpreter!.getInputTensor(i);
          print('  Input $i: shape=${tensor.shape}, type=${tensor.type}');
        }

        print('Model output details:');
        for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
          final tensor = _interpreter!.getOutputTensor(i);
          print('  Output $i: shape=${tensor.shape}, type=${tensor.type}');
        }

        _isInitialized = true;
        print('FaceEmbedding model loaded and initialized successfully');
        return true;
      } else {
        print('ERROR: Interpreter is null after loading');
        return false;
      }
    } catch (e) {
      print('ERROR loading model: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Extract embeddings from a face image
  static Future<List<double>?> extractEmbedding(File imageFile) async {
    try {
      print('=== Extracting Embedding ===');
      print('Image file path: ${imageFile.path}');

      if (!_isInitialized) {
        print('Model not initialized, attempting to initialize...');
        bool initialized = await initialize();
        if (!initialized) {
          print('ERROR: Failed to initialize model');
          return null;
        }
      }

      // Check file exists and has content
      if (!await imageFile.exists()) {
        print('ERROR: Image file does not exist');
        return null;
      }

      final fileSize = await imageFile.length();
      print('Image file size: $fileSize bytes');

      if (fileSize == 0) {
        print('ERROR: Image file is empty');
        return null;
      }

      // Read and decode the image
      print('Reading image bytes...');
      Uint8List imageBytes = await imageFile.readAsBytes();
      print('Image bytes length: ${imageBytes.length}');

      print('Decoding image...');
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ERROR: Failed to decode image');
        return null;
      }

      print('Original image size: ${image.width}x${image.height}');

      // Resize to 112x112 (model input size)
      print('Resizing image to 112x112...');
      img.Image resizedImage = img.copyResize(image, width: 112, height: 112);
      print('Resized image size: ${resizedImage.width}x${resizedImage.height}');

      // Preprocess the image
      print('Preprocessing image...');
      Float32List input = _preprocessImage(resizedImage);
      print('Preprocessed input length: ${input.length}');
      print('Expected input length: ${112 * 112 * 3} (112x112x3)');
      print('First 10 preprocessed values: ${input.take(10).toList()}');

      // Prepare input and output tensors
      print('Preparing input tensor...');
      List<List<List<List<double>>>> inputTensor = [_reshapeInput(input)];
      print('Input tensor shape: [${inputTensor.length}, ${inputTensor[0].length}, ${inputTensor[0][0].length}, ${inputTensor[0][0][0].length}]');

      print('Preparing output tensor...');
      List<List<double>> outputTensor = List.generate(1, (i) => List.filled(128, 0.0));
      print('Output tensor shape: [${outputTensor.length}, ${outputTensor[0].length}]');

      // Run inference
      print('Running model inference...');
      try {
        _interpreter!.run(inputTensor, outputTensor);
        print('Model inference completed successfully');
      } catch (e) {
        print('ERROR during model inference: $e');
        print('This could be due to:');
        print('1. Input tensor shape mismatch');
        print('2. Model corruption');
        print('3. Memory issues');
        return null;
      }

      // Get the embedding (128-dimensional vector)
      List<double> embedding = outputTensor[0];
      print('Raw embedding length: ${embedding.length}');
      print('First 10 raw embedding values: ${embedding.take(10).toList()}');

      // Check for NaN or infinite values
      bool hasInvalidValues = embedding.any((value) => value.isNaN || value.isInfinite);
      if (hasInvalidValues) {
        print('WARNING: Embedding contains NaN or infinite values');
        int nanCount = embedding.where((value) => value.isNaN).length;
        int infCount = embedding.where((value) => value.isInfinite).length;
        print('NaN values: $nanCount, Infinite values: $infCount');
      }

      // L2 normalize the embedding
      print('Normalizing embedding...');
      List<double> normalizedEmbedding = _l2Normalize(embedding);
      print('Normalized embedding length: ${normalizedEmbedding.length}');
      print('First 10 normalized values: ${normalizedEmbedding.take(10).toList()}');

      // Verify normalization (should be close to 1.0)
      double norm = sqrt(normalizedEmbedding.map((x) => x * x).reduce((a, b) => a + b));
      print('Embedding L2 norm after normalization: $norm (should be ~1.0)');

      print('Embedding extraction completed successfully');
      return normalizedEmbedding;

    } catch (e) {
      print('ERROR extracting embedding: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Preprocess image according to the model's training preprocessing
  static Float32List _preprocessImage(img.Image image) {
    print('Preprocessing image with dimensions: ${image.width}x${image.height}');

    Float32List input = Float32List(112 * 112 * 3);
    int index = 0;

    List<double> rValues = [];
    List<double> gValues = [];
    List<double> bValues = [];

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        img.Pixel pixel = image.getPixel(x, y);

        // Extract RGB values
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Apply the same preprocessing as training: subtract 128, multiply by 0.0078125
        // double processedR = (r - 128) * 0.0078125;
        // double processedG = (g - 128) * 0.0078125;
        // double processedB = (b - 128) * 0.0078125;

        // Apply standard FaceNet preprocessing: (value - 127.5) / 128.0
        double processedR = (r - 127.5) / 128.0;
        double processedG = (g - 127.5) / 128.0;
        double processedB = (b - 127.5) / 128.0;

        input[index++] = processedR;
        input[index++] = processedG;
        input[index++] = processedB;

        // Collect sample values for debugging
        if (rValues.length < 10) {
          rValues.add(processedR);
          gValues.add(processedG);
          bValues.add(processedB);
        }
      }
    }

    print('Sample preprocessed RGB values:');
    print('R: $rValues');
    print('G: $gValues');
    print('B: $bValues');

    return input;
  }

  // Reshape input for the model
  static List<List<List<double>>> _reshapeInput(Float32List input) {
    print('Reshaping input from flat array to 3D tensor...');

    List<List<List<double>>> reshaped = List.generate(112, (i) =>
        List.generate(112, (j) =>
            List.generate(3, (k) => input[i * 112 * 3 + j * 3 + k])));

    print('Reshape completed. Output shape: [${reshaped.length}, ${reshaped[0].length}, ${reshaped[0][0].length}]');
    return reshaped;
  }

  // L2 normalize the embedding vector
  static List<double> _l2Normalize(List<double> vector) {
    print('Computing L2 normalization...');

    double sumOfSquares = vector.map((x) => x * x).reduce((a, b) => a + b);
    double norm = sqrt(sumOfSquares);

    print('Sum of squares: $sumOfSquares');
    print('L2 norm: $norm');

    if (norm == 0 || norm.isNaN || norm.isInfinite) {
      print('WARNING: Invalid norm value: $norm, returning original vector');
      return vector;
    }

    List<double> normalized = vector.map((x) => x / norm).toList();

    // Verify normalization
    double verifyNorm = sqrt(normalized.map((x) => x * x).reduce((a, b) => a + b));
    print('Verification norm after normalization: $verifyNorm');

    return normalized;
  }

  // Calculate cosine similarity between two embeddings
  static double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      print('ERROR: Embedding length mismatch in cosine similarity');
      return 0.0;
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    final d1 = sqrt(norm1), d2 = sqrt(norm2);
    if (d1 == 0.0 || d2 == 0.0) return 0.0;
    return dotProduct / (d1 * d2);
  }

  static void dispose() {
    print('Disposing Face Embedding Service...');
    _interpreter?.close();
    _isInitialized = false;
    print('Face Embedding Service disposed');
  }

  static List<double> computeAverageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];

    int embeddingSize = embeddings[0].length;
    List<double> avgEmbedding = List.filled(embeddingSize, 0.0);

    // Sum all embeddings
    for (List<double> embedding in embeddings) {
      for (int i = 0; i < embeddingSize; i++) {
        avgEmbedding[i] += embedding[i];
      }
    }

    // Divide by count to get average
    for (int i = 0; i < embeddingSize; i++) {
      avgEmbedding[i] /= embeddings.length;
    }

    // L2 normalize the average
    return _l2Normalize(avgEmbedding);
  }

}

