import 'dart:ffi';
import 'package:bolt_engine/rendering/vulkan/swap_chain/swap_chain.dart';
import 'package:bolt_engine/rendering/vulkan/vulkan_device_helpers.dart';
import 'package:ffi/ffi.dart';
import 'package:vulkan/vulkan.dart';
import 'package:logger/logger.dart';

var logger = Logger();

List<String> getSupportedInstanceLayers() {
  Pointer<Uint32> layerCount = calloc<Uint32>();
  vkEnumerateInstanceLayerProperties(layerCount, nullptr);

  Pointer<VkLayerProperties> layerProperties =
      calloc.allocate(sizeOf<VkLayerProperties>() * layerCount.value);

  vkEnumerateInstanceLayerProperties(layerCount, layerProperties);
  logger.d(layerCount.value);
  List<String> supported = [];

  for (int i = 0; i < layerCount.value; i++) {
    Pointer<Utf8> name =
        Pointer.fromAddress(layerProperties.elementAt(i).address);
    String eName = name.toDartString();
    supported.add(eName);
  }
  return supported;
}

List<String> getOptionalExtensions() {
  Pointer<Uint32> extensionCount = calloc<Uint32>();
  vkEnumerateInstanceExtensionProperties(nullptr, extensionCount, nullptr);

  Pointer<VkExtensionProperties> extensionProperties =
      calloc.allocate(sizeOf<VkExtensionProperties>() * extensionCount.value);

  vkEnumerateInstanceExtensionProperties(
      nullptr, extensionCount, extensionProperties);

  List<String> supported = [];

  for (int i = 0; i < extensionCount.value; i++) {
    Pointer<Utf8> name =
        Pointer.fromAddress(extensionProperties.elementAt(i).address);
    String eName = name.toDartString();
    supported.add(eName);
  }
  return supported;
}

(Pointer<VkPhysicalDevice>, int) getPhysicalDevices(
    Pointer<VkInstance> instance) {
  Pointer<Uint32> deviceCount = calloc<Uint32>();
  vkEnumeratePhysicalDevices(instance, deviceCount, nullptr);
  logger.d("${deviceCount.value} hardware devices available");

  if (deviceCount.value == 0) {
    return (nullptr, -1);
  }

  Pointer<VkPhysicalDevice> physicalDevices =
      calloc.allocate(sizeOf<VkPhysicalDevice>() * deviceCount.value);
  Pointer<Pointer<VkPhysicalDevice>> pPhysicaldevices =
      Pointer.fromAddress(physicalDevices.address);
  vkEnumeratePhysicalDevices(instance, deviceCount, pPhysicaldevices);
  return (physicalDevices, deviceCount.value);
}

bool isDeviceSuitable(Pointer<VkPhysicalDevice> device,
    Pointer<VkSurfaceKHR> surface, List<String> requiredExtensions) {
  QueueFamilyIndices indices = findQueueFamilies(device.ref, surface.ref);

  bool extensionsSupported =
      checkDeviceExtensionSupport(device.ref, requiredExtensions);

  bool swapChainAdequate = false;
  if (extensionsSupported) {
    SwapChainSupportDetails swapChainSupport =
        querySwapChainSupport(device.ref, surface.ref);
    swapChainAdequate = swapChainSupport.formatsLength! > 0 &&
        swapChainSupport.presentModesLength! > 0;
  }

  return indices.isComplete() && extensionsSupported && swapChainAdequate;
}

bool checkDeviceExtensionSupport(
    VkPhysicalDevice device, List<String> requiredExtensions) {
  Pointer<Uint32> extensionCount = calloc<Uint32>();
  vkEnumerateDeviceExtensionProperties(
      device.pointer, nullptr, extensionCount, nullptr);
  logger.d(extensionCount.value);

  Pointer<VkExtensionProperties> availableExtensions =
      calloc.allocate(sizeOf<VkExtensionProperties>() * extensionCount.value);
  vkEnumerateDeviceExtensionProperties(
      device.pointer, nullptr, extensionCount, availableExtensions);

  //std::set<std::string> requiredExtensions(deviceExtensions.begin(), deviceExtensions.end());

  List<String> aExtensions = [];

  List<String> unavailableExtensions = List<String>.from(requiredExtensions);
  for (int i = 0; i < extensionCount.value; i++) {
    Pointer<Utf8> str =
        Pointer.fromAddress(availableExtensions.elementAt(i).address);
    String eString = str.toDartString();

    aExtensions.add(eString);

    if (unavailableExtensions.contains(eString)) {
      unavailableExtensions.remove(eString);
    }
  }

  logger.d("Available Extensions:");
  logger.d(aExtensions);
  if (unavailableExtensions.isNotEmpty) {
    logger.w("Warning: Missing Extensions: $unavailableExtensions");
  }

  return unavailableExtensions.isEmpty;

  //return requiredExtensions.empty();
}

Pointer<VkPhysicalDevice> findSuitableDevice(
    Pointer<VkPhysicalDevice> devices,
    int devicesLength,
    Pointer<VkSurfaceKHR> surface,
    List<String> requiredExtensions) {
  for (int i = 0; i < devicesLength; i++) {
    Pointer<VkPhysicalDevice> device = devices.elementAt(i);
    if (isDeviceSuitable(device, surface, requiredExtensions)) {
      logger.d("Found Suitable Device");
      logger.d(device.ref);
      return device;
    }
  }

  logger.d("Could not find suitable device");
  throw Error();
}

Pointer<Pointer<Utf8>> convertListToCStyle(List<String> strings) {
  if (strings.isEmpty) {
    return nullptr;
  }
  //strings = ["TEST1", "ALPHA2"];

  List<Pointer<Utf8>> utf8PointerList =
      strings.map((str) => str.toNativeUtf8()).toList();
  logger.d(utf8PointerList);
  logger.d(utf8PointerList[0].length);

  int totalNeededMemory = 0;

  for (int i = 0; i < strings.length; i++) {
    totalNeededMemory += strings[i].length;
    totalNeededMemory += 1; // allocate space for a null character.
  }

  logger.d(totalNeededMemory);

  logger.d("Read all of strings");

  final Pointer<Pointer<Utf8>> pointerPointer =
      calloc.allocate(totalNeededMemory);

  logger.d("Allocating Pointer<Pointer<Utf8>>");

  int ctr = 0;

  strings.asMap().forEach((index, utf) {
    pointerPointer[ctr] = utf.toNativeUtf8();
    ctr += utf.length;
    ctr += 1; // Save room for null chracter.

    logger.d(
        "$index - ${utf8PointerList[index]} - ${utf8PointerList[index].length}");
    pointerPointer[index] = utf8PointerList[index];
  });
  logger.d(pointerPointer.value);
  return pointerPointer;
}
