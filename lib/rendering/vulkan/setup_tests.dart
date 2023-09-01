import 'package:bolt_engine/rendering/vulkan/vulkan_helpers.dart';

void assertSupportedExtensions(List<String> requiredOptions) {
  List<String> availableExtensions = getOptionalExtensions();
  for (String option in requiredOptions) {
    if (!availableExtensions.contains(option)) {
      throw Error();
    }
  }

  print('${requiredOptions.length} required extensions available');
}

void assertSupportedLayers(List<String> requiredOptions) {
  List<String> availableExtensions = getSupportedInstanceLayers();
  for (String option in requiredOptions) {
    if (!availableExtensions.contains(option)) {
      throw Error();
    }
  }

  print('${requiredOptions.length} required validation layers available');
}
