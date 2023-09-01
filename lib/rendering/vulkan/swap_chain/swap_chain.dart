import 'dart:ffi';
import 'package:bolt_engine/rendering/vulkan/vulkan_device_helpers.dart';
import 'package:ffi/ffi.dart';
import 'package:logger/logger.dart';
import 'package:vulkan/vulkan.dart';
import 'package:glfw/glfw.dart';

var logger = Logger(printer: HybridPrinter(PrettyPrinter(), info: SimplePrinter(), debug: SimplePrinter()));

class SwapChainSupportDetails {
  Pointer<VkSurfaceCapabilitiesKHR>? mCapabilities;
  Pointer<VkSurfaceFormatKHR>? mFormats;
  Pointer<VkPresentModeKHR>? mPresentModes;

  List<VkSurfaceCapabilitiesKHR> getCapabilities() {
    print(mCapabilities);
    return [];
  }

  List<VkSurfaceFormatKHR> get formats {
    print(formatsLength);

    List<VkSurfaceFormatKHR> retFormats = [];
    for (int i = 0; i < formatsLength!; i++) {
      Pointer<VkSurfaceFormatKHR> aString = Pointer.fromAddress(mFormats!.elementAt(i).address);
      retFormats.add(aString.ref);
    }
    return retFormats;
  }

  VkSurfaceCapabilitiesKHR get capabilities {
    print("Getting Capabilities");
    Pointer<VkSurfaceCapabilitiesKHR> aString = Pointer.fromAddress(mCapabilities!.address);
    print("Got capabilities");
    return aString.ref;
  }

  List<Pointer<VkPresentModeKHR>> get presentModes {
    List<Pointer<VkPresentModeKHR>> retFormats = [];
    for (int i = 0; i < presentModesLength!; i++) {
      Pointer<VkPresentModeKHR> aString = Pointer.fromAddress(mPresentModes!.elementAt(i).address);
      retFormats.add(aString);
    }
    return retFormats;
  }

  int? formatsLength;
  int? presentModesLength;
}

SwapChainSupportDetails querySwapChainSupport(VkPhysicalDevice device, VkSurfaceKHR surface) {
  SwapChainSupportDetails details = SwapChainSupportDetails();

  details.mCapabilities = calloc.allocate(sizeOf<VkSurfaceCapabilitiesKHR>());

  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.pointer, surface.pointer, details.mCapabilities!);

  Pointer<Uint32> formatCount = calloc<Uint32>();
  vkGetPhysicalDeviceSurfaceFormatsKHR(device.pointer, surface.pointer, formatCount, nullptr);

  if (formatCount.value != 0) {
    details.mFormats = calloc.allocate(formatCount.value * sizeOf<VkSurfaceFormatKHR>());
    vkGetPhysicalDeviceSurfaceFormatsKHR(device.pointer, surface.pointer, formatCount, details.mFormats!);
  }

  details.formatsLength = formatCount.value;

  Pointer<Uint32> presentModeCount = calloc<Uint32>();
  print("Getting VK Physical Device Surface Present Modes");
  vkGetPhysicalDeviceSurfacePresentModesKHR(device.pointer, surface.pointer, presentModeCount, nullptr);
  print("Present Mode Count: ${presentModeCount.value}");
  if (presentModeCount.value != 0) {
    details.mPresentModes = calloc.allocate(presentModeCount.value * sizeOf<VkPresentModeKHR>());
    vkGetPhysicalDeviceSurfacePresentModesKHR(device.pointer, surface.pointer, presentModeCount, details.mPresentModes!);
  }

  details.presentModesLength = presentModeCount.value;

  print("Got Swap Chain Support Details");

  return details;
}

VkSurfaceFormatKHR chooseSwapSurfaceFormat(List<VkSurfaceFormatKHR> availableFormats) {
  for (VkSurfaceFormatKHR format in availableFormats) {
    if (format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR && format.format == VK_FORMAT_B8G8R8A8_SRGB) {
      return format;
    }
  }
  return availableFormats[0];
}

VkPresentModeKHRDart chooseSwapPresentMode(List<Pointer<VkPresentModeKHR>> availablePresentModes) {
  for (Pointer<VkPresentModeKHR> presentMode in availablePresentModes) {
    if (presentMode.value == VK_PRESENT_MODE_MAILBOX_KHR) {
      return presentMode.value;
    }
  }

  return VK_PRESENT_MODE_FIFO_KHR;
}

VkExtent2D chooseSwapExtent(VkSurfaceCapabilitiesKHR capabilities, Pointer<GLFWwindow> window) {
  if (capabilities.currentExtent.width != 0x7fffffff) {
    return capabilities.currentExtent;
  } else {
    Pointer<Int32> width = calloc<Int32>();
    Pointer<Int32> height = calloc<Int32>();
    glfwGetFramebufferSize(window, width, height);

    Pointer<VkExtent2D> actualExtent = calloc<VkExtent2D>();
    actualExtent.ref.height = height.value;
    actualExtent.ref.width = width.value;

    actualExtent.ref.width = actualExtent.ref.width.clamp(capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
    actualExtent.ref.height = actualExtent.ref.height.clamp(capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

    return actualExtent.ref;
  }
}

(Pointer<Pointer<VkSwapchainKHR>>, VkSurfaceFormatKHR, VkExtent2D, Pointer<Pointer<VkImage>>, int) createSwapChain(
    VkPhysicalDevice physicalDevice, VkSurfaceKHR surface, Pointer<GLFWwindow> window, Pointer<Pointer<VkDevice>> device) {
  SwapChainSupportDetails swapChainSupport = querySwapChainSupport(physicalDevice, surface);
  print("HERE");

  VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
  VkPresentModeKHRDart presentMode = chooseSwapPresentMode(swapChainSupport.presentModes);
  VkExtent2D extent = chooseSwapExtent(swapChainSupport.capabilities, window);

  print(surfaceFormat);

  int imageCount = swapChainSupport.capabilities.minImageCount + 1;

  if (swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount) {
    imageCount = swapChainSupport.capabilities.maxImageCount;
  }

  print(imageCount);

  Pointer<VkSwapchainCreateInfoKHR> createInfo = calloc<VkSwapchainCreateInfoKHR>();
  createInfo.ref.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  createInfo.ref.surface = surface.pointer;

  createInfo.ref.minImageCount = imageCount;
  createInfo.ref.imageFormat = surfaceFormat.format;
  createInfo.ref.imageColorSpace = surfaceFormat.colorSpace;
  createInfo.ref.imageExtent = extent;
  createInfo.ref.imageArrayLayers = 1;
  createInfo.ref.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

  print("Finding Queue Families");

  QueueFamilyIndices indices = findQueueFamilies(physicalDevice, surface);

  Pointer<Uint32> queueFamilyIndices = calloc.allocate(sizeOf<Uint32>() * 2);

  queueFamilyIndices.elementAt(0).value = indices.graphicsFamily!;
  queueFamilyIndices.elementAt(1).value = indices.presentFamily!;

  print("Set queue Family Indices");

  print("if statement branch: ${indices.graphicsFamily != indices.presentFamily}");
  if (indices.graphicsFamily != indices.presentFamily) {
    createInfo.ref.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
    createInfo.ref.queueFamilyIndexCount = 2;
    createInfo.ref.pQueueFamilyIndices = queueFamilyIndices;
  } else {
    createInfo.ref.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    createInfo.ref.queueFamilyIndexCount = 0; // Optional
    createInfo.ref.pQueueFamilyIndices = nullptr; // Optional
  }
  print("Escaped if Statement");
  print(swapChainSupport.capabilities.currentTransform);
  print("Read value");

  createInfo.ref.preTransform = swapChainSupport.capabilities.currentTransform;
  print("Set pre transform");
  createInfo.ref.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

  print("Set pretransform and composite alpha");

  createInfo.ref.presentMode = presentMode;
  createInfo.ref.clipped = VK_TRUE;
  createInfo.ref.oldSwapchain = nullptr;
  print("Finished Setting Create Info details");

  Pointer<VkSwapchainKHR> swapChain = calloc<VkSwapchainKHR>();
  Pointer<Pointer<VkSwapchainKHR>> ppSwapChain = Pointer.fromAddress(swapChain.address);
  print("CREATING SWAP CHAIN");
  if (vkCreateSwapchainKHR(device.value, createInfo, nullptr, ppSwapChain) != VK_SUCCESS) {
    print("ERROR");
  } else {
    print("Successfully Created Swapchain");
  }

  Pointer<Uint32> pImageCount = calloc<Uint32>();

  vkGetSwapchainImagesKHR(device.value, ppSwapChain.value, pImageCount, nullptr);

  print(pImageCount.value);

  Pointer<VkImage> vkImages = calloc.allocate(sizeOf<VkImage>() * pImageCount.value);

  Pointer<Pointer<VkImage>> ppVkImages = Pointer.fromAddress(vkImages.address);

  vkGetSwapchainImagesKHR(device.value, ppSwapChain.value, pImageCount, ppVkImages);

  return (ppSwapChain, surfaceFormat, extent, ppVkImages, pImageCount.value);
}

typedef VkPresentModeKHRDart = int;
