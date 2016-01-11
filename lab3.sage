import random

class User:
	def __init__(self, user_name, size, password):
		self.MOD = IntegerModRing(2)
		self.vector_space = VectorSpace(self.MOD, size)

		self.user_name = user_name
		self.password = self.vector_space([int(i) for i in password.split(' ')])


	def interactive_challenge_answer(self, challenge):
		'''
		Returns response for a given challenge which is value entered by user. If wrong value is entered then in the further process the verificaiton will fail.
		'''
		#response = self.vector_space([int(i) for i in raw_input('answer:\t').split(' ')]) * challenge
		return int(raw_input('Insert answer:\t').strip())


	def calculated_challenge_answer(self, challenge):
		'''
		Calculates and returns true answer of challenge which is calculated as dot product of challenge and password.
		'''
		return challenge * self.password
	
		

class Server:
	def __init__(self, user_name, size, num_challenges, password, error_rate=0.1):
		self.user_name = user_name
		
		self.vector_size = size
		self.num_challenges = num_challenges
		self.MOD = IntegerModRing(2)
		self.vector_space = VectorSpace(self.MOD, size)

		self.password = self.vector_space([int(i) for i in password.split(' ')])
		
		# added for the modified protocol, where wrong answer will be accepted occasionally 		
		self.correct_answers = 0
		self.wrong_answers = 0
		self.allowed_error_rate = error_rate

	def random_challenge(self):
		'''
		Returns random challenge of vector_size length.
		'''
		challenge = self.vector_space([random.randint(0,1) for i in xrange(self.vector_size)])
		return challenge

	def challenge_response(self, challenge_number, challenge, answer):
		'''
		Returns True if the answer for the challenge is correct and False otherwise.
		'''
		ok = challenge * self.password == answer
		if ok:
			print '%d answer correct' % challenge_number
			return True
		else:
			print '%d answer wrong' % challenge_number
			return False

	def challenge_response_modified(self, challenge_number, challenge, answer):
		ok = challenge * self.password == answer
		if ok:
			self.correct_answers += 1
			print '%d answer correct' % challenge_number
			return True
		else:
			self.wrong_answers += 1
			print '%d answer wrong' % challenge_number
			if 1.0 * self.wrong_answers / self.correct_answers > self.allowed_error_rate:
				return False
			else:
				return True

	def authenticate_user(self, user, interactive=True):
		'''
		Simulation of the authentication process. Returns False when some answer is wrong. If all answers are correct returns True.
		'''	
		for i in xrange(1, self.num_challenges + 1):
			challenge = self.random_challenge()
			print 'Challenge %d sent: %s' % (i, str(challenge))
			if interactive:
				answer = user.interactive_challenge_answer(challenge)
			else:
				answer = user.calculated_challenge_answer(challenge)
			print 'Answer %d sent: %s' % (i, str(answer))
			verified = self.challenge_response(i, challenge, answer)
			if verified:
				print 'Challenge %d succesfully passed!' % i
			else:
				print 'Challenge %d not passed! Authentication refused' % i
				return False
			
		print 'All challenges passed!'
		return True

				
class Observer:
	def __init__(self, name, size):
		self.MOD = IntegerModRing(2)
		self.vector_space = VectorSpace(self.MOD, size)

		self.size = size
		self.name = name
		self.challenges = []
		self.answers = []

	def observe(self, server, user, interactive=False):
		'''
		Similar simulation like in authenticat_user() in Server, but here is introduced an observer which collects all lineary independent challenges and its corresponding answers and when collects enough it prints the correct password. Also it returns the number of obserations needed till sure guess of password.
		'''
		self.challenges = []
		self.answers = []
		for i in xrange(1, server.num_challenges + 1):
			challenge = server.random_challenge()
			print 'Challenge %d sent: %s' % (i, str(challenge))
			if interactive:
				answer = user.interactive_challenge_answer(challenge)
			else:
				answer = user.calculated_challenge_answer(challenge)
			print 'Answer %d sent: %s' % (i, str(answer))
			verified = server.challenge_response(i, challenge, answer)

			self.challenges.append(challenge)
			self.answers.append(answer)

			password_sol = self.solve_system()
			if password_sol is None:
				print 'Password was not guessed with %d challenges and answers observed' % i
			else:
				print 'The true password is %s. Found after %d observations' % (str(password_sol), i)
				return i

		return 1000000000000 # very long number to penalize if we have some case when answer could not be found		


	def solve_system(self):
		'''
		Auxiliary method which collects the new challenges which are linearly independent of the previous ones. When enough data is collected it returns the password by solving the system.
		'''
		matrix_space = MatrixSpace(self.MOD, len(self.challenges), self.size)
		A = matrix_space(self.challenges)
		#print A
		VS = VectorSpace(self.MOD, len(self.answers))
		b = VS(self.answers)
	
		echelon_form = A.rref()
		as_array = [i for i in echelon_form]
		independent = []
		independent_answers = []
		useful_challenges = []

		for i in xrange(len(self.challenges)):
			if sum([1 for j in echelon_form[i] if j > 0]) > 0:# list comprehension used to go out of the GF(2)
				#print '\t' + self.challenges[i]
				independent.append(self.challenges[i])
				independent_answers.append(self.answers[i])

		self.challenges = independent
		self.answers = independent_answers

		matrix_space = MatrixSpace(self.MOD, len(independent), self.size)
		A = matrix_space(independent)

		if len(independent) != self.size or A.determinant() == 0:
			return None
		try:
			x = A.solve_right(b)
			return x
		except:
			return None			


	def average_observations_needed_for_successful_attack(self, username, trials, pass_size, num_challenges=1000):
		'''
		Returns average time needed to crack password of pass_size password size.
		'''
		total = 0
		for i in xrange(trials):
			password = ' '.join([str(random.randint(0,1)) for j in xrange(pass_size)])
			print type(password)
			server = Server(username, pass_size, num_challenges, password)
			user = User(username, pass_size, password)
			total += self.observe(server, user)
		return 1.0 * total / trials

def test_user_authentication():
	'''
	Used to test user_authentication() on user provided input.
	'''
	print 'Testing User authenticcation by server'
	username = raw_input('Insert your username:\t')
	size = int(raw_input('Insert password length:\t'))
	password = raw_input('Insert your password in a space separated format containing binary values:\t')
	num_challenges = int(raw_input('Insert number of challenges you want to use before granting access:\t'))

	user = User(username, size, password)
	server = Server(username, size, num_challenges, password)

	server.authenticate_user(user)

def test_one_observation():
	'''
	Used to test observe() on user entered data.
	'''
	print 'Testing observation by Observer'
	
	username = raw_input('Insert your username:\t')
	size = int(raw_input('Insert password length:\t'))
	password = raw_input('Insert your password in a space separated format containing binary values:\t')
	num_challenges = int(raw_input('Insert number of challenges you want to use before granting access:\t'))

	user = User(username, size, password)
	server = Server(username, size, num_challenges, password)

	observer = Observer('Oscar', server.vector_size)
	observer.observe(server, user)


def test_average_number_of_observations():
	'''
	Used to test the average number of needed observations on user defined input.
	'''
	username = raw_input('Insert your username:\t')
	vector_size = int(raw_input('Insert password length:\t'))
	num_challenges = int(raw_input('Insert maximum number of challenges you want to use before granting access:\t'))
	tests_count = int(raw_input('Insert number of tests on which want to find average value. The greater the value, the better the precision:\t'))
	observer = Observer(username, vector_size)
	print 'Average number of observations needed for finding password of length %d is %f' % (vector_size, observer.average_observations_needed_for_successful_attack(username, tests_count, vector_size, num_challenges=1000))


#test_user_authentication()
#test_one_observation()
test_average_number_of_observations()
		

# Improvement. Part 3


