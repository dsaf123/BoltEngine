import 'dart:ffi';

import 'package:bolt_engine/rendering/vulkan/vulkan_device_helpers.dart';
import 'package:bolt_engine/rendering/vulkan/vulkan_helpers.dart';
import 'package:ffi/ffi.dart';
import 'package:logger/logger.dart';
import 'package:vulkan/vulkan.dart';

var logger = Logger();

Pointer<Pointer<VkDevice>> createLogicalDevice(Pointer<VkPhysicalDevice> physicalDevice, VkSurfaceKHR surface, List<String> deviceExtensions,
    Pointer<Pointer<VkDevice>>? device, bool enableValidationLayers, List<String> validationLayers) {
  logger.i("CREATE LOGICAL DEVICE");
  QueueFamilyIndices indices = findQueueFamilies(physicalDevice.ref, surface);
  Pointer<Float> queuePriority = calloc<Float>();

  queuePriority.value = 1;

  List<Pointer<VkDeviceQueueCreateInfo>> queueCreateInfos = [];

  Set uniqueQueueFamilies = {indices.graphicsFamily, indices.presentFamily};
  logger.d(uniqueQueueFamilies);
  for (int queueFamily in uniqueQueueFamilies) {
    Pointer<VkDeviceQueueCreateInfo> queueCreateInfo = calloc<VkDeviceQueueCreateInfo>();

    queueCreateInfo.ref.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.ref.queueFamilyIndex = queueFamily;
    queueCreateInfo.ref.queueCount = 1;
    queueCreateInfo.ref.pQueuePriorities = queuePriority;

    queueCreateInfos.add(queueCreateInfo);
  }

  Pointer<VkPhysicalDeviceFeatures> deviceFeatures = calloc<VkPhysicalDeviceFeatures>();

  Pointer<VkDeviceQueueCreateInfo> pQueueCreateInfos = calloc.allocate(sizeOf<VkDeviceQueueCreateInfo>() * queueCreateInfos.length);

  logger.d(pQueueCreateInfos);

  for (int i = 0; i < queueCreateInfos.length; i++) {
    pQueueCreateInfos[i] = queueCreateInfos[i].ref;
  }

  logger.d(queueCreateInfos.length);

  Pointer<VkDeviceCreateInfo> createInfo = calloc<VkDeviceCreateInfo>();
  createInfo.ref.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  createInfo.ref.pQueueCreateInfos = pQueueCreateInfos;
  createInfo.ref.queueCreateInfoCount = queueCreateInfos.length;
  createInfo.ref.pEnabledFeatures = deviceFeatures;
  createInfo.ref.enabledExtensionCount = deviceExtensions.length;
  createInfo.ref.ppEnabledExtensionNames = convertListToCStyle(deviceExtensions);

  Pointer<VkDevice> pLogicalDevice = calloc<VkDevice>();

  device = Pointer.fromAddress(pLogicalDevice.address);

  if (enableValidationLayers) {
    createInfo.ref.enabledLayerCount = validationLayers.length;
    createInfo.ref.ppEnabledLayerNames = convertListToCStyle(validationLayers);
  } else {
    createInfo.ref.enabledLayerCount = 0;
  }

  logger.i(physicalDevice.ref);
  logger.i(physicalDevice.address);
  logger.i(createInfo.address);
  logger.i(device.address);

  logger.d(physicalDevice.ref.pointer.ref);

  int result = vkCreateDevice(physicalDevice.ref.pointer, createInfo, nullptr, device);
  logger.d(result);
  if (result != VK_SUCCESS) {
    logger.d("ERROR");
  } else {
    logger.d("SUCCESS");
  }
  Pointer<VkQueue> presentQueue = calloc<VkQueue>();
  Pointer<Pointer<VkQueue>> pPresentQueue = Pointer.fromAddress(presentQueue.address);
  vkGetDeviceQueue(device.value, indices.presentFamily!, 0, pPresentQueue);
  return device;
}
