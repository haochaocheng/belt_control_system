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
