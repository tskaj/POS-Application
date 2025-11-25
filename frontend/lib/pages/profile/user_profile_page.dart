import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/models.dart';
import '../../providers/providers.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String? _selectedGender;
  File? _selectedImage;
  bool _isEditing = false;
  bool _isLoading = false;
  Uint8List? _imageBytes;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    // Load profile data after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If profile is not loaded, fetch it first
    if (authProvider.userProfile == null) {
      await authProvider.getUserProfile();
    }

    final profile = authProvider.userProfile;
    if (profile != null) {
      setState(() {
        _phoneController.text = profile.phone ?? '';
        _addressController.text = profile.address ?? '';
        _selectedGender = profile.gender;
        _dobController.text = profile.dob ?? '';
      });
      // Load image bytes if profile picture exists and is local
      if (profile.profilePicture != null &&
          !profile.profilePicture!.startsWith('http')) {
        try {
          _imageBytes = await File(
            '${Directory.current.path}/${profile.profilePicture}',
          ).readAsBytes();
          setState(() {});
        } catch (e) {
          print('Error loading image bytes: $e');
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;

    final profileData = {
      'user_id': authProvider.user!.id.toString(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'gender': _selectedGender,
      'dob': _dobController.text.trim(),
    };

    String? relativePath;

    // If a new image is selected, save it locally and send the path
    if (_selectedImage != null) {
      try {
        String profilesDir = '${Directory.current.path}/assets/images/profiles';
        Directory dir = Directory(profilesDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        String fileName = 'profile_${authProvider.user!.id}.jpg';
        File localFile = File('$profilesDir/$fileName');
        await localFile.writeAsBytes(await _selectedImage!.readAsBytes());
        _imageBytes = await _selectedImage!.readAsBytes();
        relativePath = 'assets/images/profiles/$fileName';
      } catch (e) {
        print('Error saving image locally: $e');
        // Continue without image if saving fails
      }
    } else {
      // Only include profile_picture if it exists and not empty
      if (profile?.profilePicture != null &&
          profile!.profilePicture!.isNotEmpty) {
        profileData['profile_picture'] = profile.profilePicture;
      }
    }

    try {
      bool success;

      // Check if profile exists, if not, create it
      if (authProvider.userProfile == null) {
        success = await authProvider.createUserProfile(profileData);
      } else {
        success = await authProvider.updateUserProfile(profileData);
      }

      if (success && mounted) {
        // Override the profile_picture with local path if we saved locally
        if (relativePath != null) {
          authProvider.userProfile!.profilePicture = relativePath;
          authProvider.incrementImageVersion();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Stay in edit mode and reload data
        _loadProfileData();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to update profile';
        if (e.toString().contains('Session expired')) {
          errorMessage = 'Session expired. Please login again.';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Authentication failed. Please login again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final profile = authProvider.userProfile;

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Profile'),
            backgroundColor: const Color(0xFF0D1845),
            foregroundColor: Colors.white,
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _isEditing = true),
                )
              else
                TextButton(
                  onPressed: () {
                    setState(() => _isEditing = false);
                    _loadProfileData(); // Reset changes
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: _isLoading && authProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.getUserProfile();
                    await _loadProfileData();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Picture Section
                        _buildProfilePictureSection(profile),

                        const SizedBox(height: 24),

                        // Basic User Info (Read-only)
                        _buildBasicUserInfo(user),

                        const SizedBox(height: 24),

                        // Extended Profile Form
                        _buildExtendedProfileForm(profile),

                        const SizedBox(height: 24),

                        // Delete User Button
                        _buildDeleteUserSection(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfilePictureSection(UserProfile? profile) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Profile Picture',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              CircleAvatar(
                key: ValueKey(
                  '${profile?.profilePicture ?? 'default'}_${authProvider.imageVersion}',
                ),
                radius: 70,
                backgroundColor: Colors.grey[300],
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (_imageBytes != null ? MemoryImage(_imageBytes!) : null),
                child:
                    (_selectedImage == null &&
                        (profile?.profilePicture == null ||
                            profile!.profilePicture!.isEmpty))
                    ? const Icon(Icons.person, size: 70, color: Colors.grey)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1845),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
            ],
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: const Text(
                'Image selected. It will be saved locally and the path sent with the profile update.',
                style: TextStyle(color: Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicUserInfo(User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Full Name', user?.fullName ?? 'N/A'),
          _buildInfoRow('Email', user?.email ?? 'N/A'),
          _buildInfoRow('Role', user?.roleId == '1' ? 'Admin' : 'User'),
          _buildInfoRow('Status', user?.status ?? 'N/A'),
          _buildInfoRow(
            'Member Since',
            user?.createdAt != null
                ? DateFormat('MMM dd, yyyy').format(user!.createdAt)
                : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedProfileForm(UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extended Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              enabled: _isEditing,
              maxLines: 3,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length < 5) {
                  return 'Please enter a valid address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Gender
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _genderOptions.map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: _isEditing
                  ? (value) => setState(() => _selectedGender = value)
                  : null,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date of Birth
            TextFormField(
              controller: _dobController,
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context),
                      )
                    : null,
              ),
              enabled: _isEditing,
              readOnly: true,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    final dob = DateTime.parse(value);
                    final now = DateTime.now();
                    final age =
                        now.year -
                        dob.year -
                        (now.month < dob.month ||
                                (now.month == dob.month && now.day < dob.day)
                            ? 1
                            : 0);
                    if (age < 13) {
                      return 'You must be at least 13 years old';
                    }
                    if (age > 120) {
                      return 'Please enter a valid date of birth';
                    }
                  } catch (e) {
                    return 'Please enter a valid date';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_isEditing)
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Save Profile'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteUserSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'If you wish to permanently delete your account and all associated data, you can do so below. This action cannot be undone.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _showDeleteConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete Account'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    final TextEditingController confirmationController =
        TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. This will permanently delete your account and remove all your data from our servers.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please type "Delete User" to confirm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmationController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type "Delete User" here',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (confirmationController.text.trim() == 'Delete User') {
                  Navigator.of(context).pop(); // Close dialog
                  await _deleteUserAccount();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please type "Delete User" to confirm'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUserAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await authProvider.deleteUser();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login page
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to delete account';
        if (e.toString().contains('Session expired')) {
          errorMessage = 'Session expired. Please login again.';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}
