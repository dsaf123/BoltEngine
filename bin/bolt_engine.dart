import 'dart:ffi';

import 'package:bolt_engine/bolt_engine.dart' as bolt_engine;
import 'package:bolt_engine/rendering/vulkan/devices/logical_device.dart';
import 'package:bolt_engine/rendering/vulkan/setup_tests.dart';
import 'package:bolt_engine/rendering/vulkan/swap_chain/swap_chain.dart';
import 'package:bolt_engine/rendering/vulkan/vulkan_helpers.dart';
import 'package:ffi/ffi.dart';
import 'package:glfw/glfw.dart';
import 'package:logger/logger.dart';
import 'package:vulkan/vulkan.dart';
import 'dart:io' show Platform;

late Pointer<GLFWwindow> window;
late Pointer<Pointer<VkInstance>> instance;

late Pointer<VkPhysicalDevice> physicalDevice;
Pointer<Pointer<VkDevice>>? device;

late Pointer<VkSurfaceKHR> surface;

late Pointer<Pointer<VkSwapchainKHR>> swapChain;

List<String> validationLayers = ["VK_LAYER_KHRONOS_validation"];

List<String> deviceExtensions = ["VK_KHR_swapchain"];

const enableValidationLayers = true;
const int width = 800;
const int height = 600;

var logger = Logger(printer: HybridPrinter(PrettyPrinter(), info: SimplePrinter(), debug: SimplePrinter()));

// initWindow initializes GLFW framework, and creates a titled window of
//     appropriate size.
// Pre: width and height global variables must be set. stores result in a global
//      Pointer to GLFWWindow object named window. GLFW must NOT be initialized
//      before running.
// Post: GLFW will be initialized. You may NOT initialize again.
void initWindow() {
  glfwInit();
  // Disable Auto Setup of OpenGL as we are using Vulkan instead.
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

  // Don't use default window resizing api... We (must) implement it ourselves.
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

  window = glfwCreateWindow(width, height, "Vulkan".toNativeUtf8(), nullptr.cast(), nullptr.cast());
}

void initVulkan() {
  createInstance();
  createWindowSurface();
  pickPhysicalDevice();
  device = createLogicalDevice(physicalDevice, surface.ref, deviceExtensions, device, enableValidationLayers, validationLayers);

  var (swap, format, extent, ppImages, imageCount) = createSwapChain(physicalDevice.ref, surface.ref, window, device!);
  swapChain = swap;

  createImageViews(ppImages, imageCount, format);
}

void createImageViews(Pointer<Pointer<VkImage>> ppImages, int imageCount, VkSurfaceFormatKHR swapChainImageFormat) {
  List<Pointer<Pointer<VkImageView>>> swapChainImageViews = [];

  for (int i = 0; i < imageCount; i++) {
    Pointer<VkImageViewCreateInfo> createInfo = calloc<VkImageViewCreateInfo>();
    createInfo.ref.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    createInfo.ref.image = ppImages.elementAt(i).value;
    createInfo.ref.viewType = VK_IMAGE_VIEW_TYPE_2D;
    createInfo.ref.format = swapChainImageFormat.format;
    createInfo.ref.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
    createInfo.ref.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
    createInfo.ref.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
    createInfo.ref.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;

    createInfo.ref.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    createInfo.ref.subresourceRange.baseMipLevel = 0;
    createInfo.ref.subresourceRange.levelCount = 1;
    createInfo.ref.subresourceRange.baseArrayLayer = 0;
    createInfo.ref.subresourceRange.layerCount = 1;

    Pointer<VkImageView> tmpImgView = calloc<VkImageView>();

    Pointer<Pointer<VkImageView>> ppImgView = Pointer.fromAddress(tmpImgView.address);

    swapChainImageViews.add(ppImgView);

    if (vkCreateImageView(device!.value, createInfo, nullptr, swapChainImageViews[i]) != VK_SUCCESS) {
      print("ERROR");
    } else {
      print("CREATED IMAGE VIEW");
    }
  }
}

void pickPhysicalDevice() {
  var (devices, numDevices) = getPhysicalDevices(instance.value);
  physicalDevice = findSuitableDevice(devices, numDevices, surface, deviceExtensions);
}

void createInstance() {
  Pointer<VkApplicationInfo> appInfo = calloc<VkApplicationInfo>();
  appInfo.ref
    ..sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    ..pNext = nullptr
    ..pApplicationName = 'Application'.toNativeUtf8()
    ..applicationVersion = makeVersion(1, 0, 0)
    ..pEngineName = 'Engine'.toNativeUtf8()
    ..engineVersion = 0
    ..apiVersion = makeVersion(1, 0, 0);

  Pointer<Uint32> glfwExtensionCount = calloc<Uint32>();
  Pointer<NativeType> glfwExtensions = glfwGetRequiredInstanceExtensions(glfwExtensionCount);

  Pointer<Pointer<Utf8>> glfwRIENative = glfwExtensions.cast<Pointer<Utf8>>();
  List<String> glfwRequiredExtensions = [];
  for (int i = 0; i < glfwExtensionCount.value; i++) {
    glfwRequiredExtensions.add(glfwRIENative.elementAt(i).value.toDartString());
  }

  logger.d(glfwRequiredExtensions);
  assertSupportedExtensions(glfwRequiredExtensions);
  logger.d("Checking for validation layers");

  if (enableValidationLayers) {
    assertSupportedLayers(validationLayers);
  }

  Pointer<VkInstanceCreateInfo> createInfo = calloc<VkInstanceCreateInfo>();

  createInfo.ref.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;

  createInfo.ref
    ..pNext = nullptr
    ..flags = 0
    ..pApplicationInfo = appInfo
    ..enabledExtensionCount = glfwExtensionCount.value
    ..ppEnabledExtensionNames = glfwRIENative
    ..enabledLayerCount = validationLayers.length;
  logger.d("Setting ppEnabledLayerNames");
  createInfo.ref.ppEnabledLayerNames = convertListToCStyle(validationLayers);
  logger.d("Created Create Info");
  instance = calloc<Pointer<VkInstance>>();
  int result = vkCreateInstance(createInfo, nullptr, instance);

  if (result != VK_SUCCESS) {
    throw Error();
  } else {
    logger.i("Vulkan Initialized Successfully");
  }
}

void createWindowSurface() {
  // Create Window Surface
  surface = calloc<VkSurfaceKHR>();

  int surfaceResult = glfwCreateWindowSurface(instance.value, window, nullptr, surface);

  if (surfaceResult != VK_SUCCESS) {
    logger.w("Error creating window surface");
  } else {
    logger.i("Successfully Created Window Surface");
  }
}

void mainLoop() {
  while (glfwWindowShouldClose(window) != GLFW_TRUE) {
    glfwSwapBuffers(window);
    glfwPollEvents();
  }
}

void cleanup() {
  logger.i("Cleaning Up Vulkan Objects");

  //vkDestroySurfaceKHR(
  //instance.value.ref.pointer.ref.pointer, surface.ref.pointer, nullptr);
  logger.i("Destroyed Vulkan Surface");

  vkDestroyInstance(instance.value.ref.pointer.ref.pointer, nullptr);
  logger.i("Destroyed Vulkan Instance");

  vkDestroySwapchainKHR(device!.value, swapChain.value, nullptr);
  logger.i("Destroyed Swapchain");

  if (device != null) {
    logger.i("Logical device is being destroyed.");
    vkDestroyDevice(device!.value, nullptr);
  } else {
    logger.w("Device was never created...");
  }

  glfwDestroyWindow(window);

  glfwTerminate();
}

void main(List<String> arguments) {
  logger.i('Hello world: ${bolt_engine.calculate()}!');
  logger.i(Platform.localHostname);
  logger.i("${Platform.operatingSystem}: ${Platform.operatingSystemVersion}");

  initWindow();
  initVulkan();

  mainLoop();
  cleanup();
}

convertCString(Array<Uint8> cstring) {
  logger.d(cstring);
}

int makeVersion(int major, int minor, int patch) => ((major) << 22) | ((minor) << 12) | (patch);
