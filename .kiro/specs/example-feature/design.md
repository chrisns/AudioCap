# User Profile Management Design

## Architecture Overview
The profile management system follows a standard MVC pattern with React frontend components communicating with REST API endpoints. Profile data is stored in the user database with file uploads handled by a separate storage service.

## Component Breakdown

### Frontend Components

#### ProfileView Component
- **Purpose**: Display current user profile in read-only mode
- **Interface**: Takes user data as props, renders profile information
- **Dependencies**: User context, ProfilePicture component

#### ProfileEditForm Component  
- **Purpose**: Editable form for updating profile information
- **Interface**: Form submission handlers, validation logic
- **Dependencies**: Form validation library, API service, FileUpload component

#### ProfilePicture Component
- **Purpose**: Display and allow upload of profile pictures
- **Interface**: Image display with upload trigger
- **Dependencies**: File upload service, image optimization

### Backend Components

#### ProfileController
- **Purpose**: Handle HTTP requests for profile operations
- **Interface**: GET /profile, PUT /profile, POST /profile/picture
- **Dependencies**: UserService, FileService, ValidationService

#### UserService
- **Purpose**: Business logic for user profile operations
- **Interface**: updateProfile(), getProfile(), validateChanges()
- **Dependencies**: User repository, email service

## Data Models

```typescript
interface UserProfile {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  bio?: string;
  profilePictureUrl?: string;
  preferences: {
    emailNotifications: boolean;
    profileVisibility: 'public' | 'private';
  };
  updatedAt: Date;
}

interface ProfileUpdateRequest {
  firstName?: string;
  lastName?: string;
  bio?: string;
  preferences?: Partial<UserProfile['preferences']>;
  currentPassword: string; // Required for verification
}
```

## API Interfaces

### GET /api/profile
- **Request**: Authorization header with JWT token
- **Response**: `{ profile: UserProfile }`
- **Errors**: 401 Unauthorized, 404 User Not Found

### PUT /api/profile  
- **Request**: `ProfileUpdateRequest` with current password
- **Response**: `{ profile: UserProfile, message: string }`
- **Errors**: 400 Validation Error, 401 Unauthorized, 403 Invalid Password

### POST /api/profile/picture
- **Request**: Multipart form data with image file
- **Response**: `{ profilePictureUrl: string }`
- **Errors**: 400 Invalid File, 413 File Too Large

### PUT /api/profile/email
- **Request**: `{ newEmail: string, currentPassword: string }`
- **Response**: `{ message: 'Verification email sent' }`
- **Errors**: 400 Invalid Email, 409 Email Already Exists

## User Flow

1. **View Profile**: User navigates to profile page and sees current information
2. **Edit Mode**: User clicks "Edit Profile" to enter edit mode
3. **Make Changes**: User updates desired fields in the form
4. **Validation**: Client-side validation provides immediate feedback
5. **Submit**: User enters current password and submits changes
6. **Server Validation**: Backend validates all changes and password
7. **Update Database**: Changes are saved to user record
8. **Confirmation**: User sees success message and updated information
9. **Email Change Flow**: If email changed, verification email is sent

## Technical Implementation Approach

- **Frontend**: React with TypeScript, React Hook Form for form management
- **State Management**: React Context for user profile state
- **Validation**: Joi/Yup schema validation on both client and server
- **File Upload**: Direct upload to AWS S3 with presigned URLs
- **Image Processing**: Sharp.js for server-side image optimization
- **Security**: Password confirmation required, rate limiting on endpoints

## Security Considerations

- **Authentication**: All endpoints require valid JWT token
- **Authorization**: Users can only update their own profiles
- **Data Protection**: Sensitive operations require password confirmation
- **Input Validation**: Strict validation and sanitization of all inputs
- **File Security**: Image uploads scanned for malware, size/type restrictions
- **Session Management**: Email changes invalidate current sessions 