# Reset GitLab root password
# Usage: docker exec gitlab bash /tmp/reset-password.sh

echo "Resetting GitLab root password..."

# Use gitlab-rails console to reset password
gitlab-rails runner "
user = User.find_by(username: 'root')
if user
  user.password = 'hao0305750218'
  user.password_confirmation = 'hao0305750218'
  user.save!
  puts 'Password reset successfully!'
else
  puts 'User not found!'
  exit 1
end
"
