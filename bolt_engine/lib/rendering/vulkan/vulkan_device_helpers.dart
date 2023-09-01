import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:vulkan/vulkan.dart';

class QueueFamilyIndices {
  int? graphicsFamily;
  int? presentFamily;

  isComplete() {
    return graphicsFamily != null && presentFamily != null;
  }
}

QueueFamilyIndices findQueueFamilies(
    VkPhysicalDevice device, VkSurfaceKHR surface) {
  // Logic to find graphics queue family
  QueueFamilyIndices indices = QueueFamilyIndices();

  Pointer<Uint32> queueFamilyCount = calloc<Uint32>();
  //print(queueFamilyCount.value);
  vkGetPhysicalDeviceQueueFamilyProperties(
      device.pointer, queueFamilyCount, nullptr);
  //print(queueFamilyCount.value);

  Pointer<VkQueueFamilyProperties> queueProperties = calloc
      .allocate(sizeOf<VkQueueFamilyProperties>() * queueFamilyCount.value);
  vkGetPhysicalDeviceQueueFamilyProperties(
      device.pointer, queueFamilyCount, queueProperties);

  for (int i = 0; i < queueFamilyCount.value; i++) {
    //print(i);
    print(queueProperties.elementAt(i).ref.queueFlags.toRadixString(2));
    if ((queueProperties.elementAt(i).ref.queueFlags & VK_QUEUE_GRAPHICS_BIT) >
        0) {
      indices.graphicsFamily = i;
    }

    Pointer<VkBool32> presentSupport = calloc<VkBool32>();
    presentSupport.value = VK_FALSE;
    vkGetPhysicalDeviceSurfaceSupportKHR(
        device.pointer, i, surface.pointer, presentSupport);

    if (presentSupport.value == VK_TRUE) {
      indices.presentFamily = i;
    }

    if (indices.isComplete()) {
      break;
    }
  }

  return indices;
}
