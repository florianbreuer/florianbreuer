# print("The following html code turns on MathJax:")
# print()
# print()
# print(r"""
# <script type="text/javascript" async="" src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML"></script>
# </div>
# """
print("Squid Tools v2, 11 October 2021")
print("By Florian Breuer, florian.breuer@newcastle.edu.au")
print()
print("Imported the following functions:")
print("  For handling QTI files:")
print("   id_generator, initialise_qti, qti_set_question_text, qti_MCQ_new, qti_set_points, qti_set_identifier,")
print("    qti_insert_question, qti_set_question_text, qti_file_upload_question_new, ET_MCQ, ET_file_upload_question, save_qti")
print()
print("  For nicer typesetting:")
print("   nicify, nicify0, plus, pplus, suppress1, Taylor")
print()
print("  For manipulating and typesetting matrices:")
print("   scramble, scramble_full, tootrivial, latexdet")
print()
print("  For handling LMS files and marking schemes:")
print("   SaveToBBfile, SaveToQtiFile, PrintMarkingScheme, TypesetMarkingScheme, SaveMarkingScheme")
print()
print("Imported the following classes:")
print("  MATHJAX")
print("  linear_system")
print("  Question_written")
print("  Question_MCQ")
print("  QuestionPool")

import itertools, functools
import random as py_random
import re
from zipfile import ZipFile
import xml.etree.ElementTree as ET
import string
import random
import ipywidgets as widgets


def id_generator(size=6, chars=string.ascii_lowercase + string.digits):
    '''Returns a (cryptographically insecure!) random identifier of length size'''
    return ''.join(random.choice(chars) for _ in range(size))

# This code defines a number of functions for manipulating QTI questions.
# It first creates some ElementTree tree from the file "qti_template.xml" and extracts some
# creates templates stored in the global variables:
#
#     qti_template
#     qti_template_upload_question
#     qti_template_MCQ
#
# Also defines methods for creating questions, inserting them into the template, and saving the result
# as a zip file ready for uploading to Canvas.

def initialise_qti(title="Squid-based question pool",
                   ident=None,
                   template_filename="qti_template.xml",
                   verbose=True):
    '''
    Initialise some globals, create a QTI assessment, return it in the form of an ElementTree.

    title : assessment title
    ident : assessment identifier. If None (default) then a random one is created.
    template_filement : the file used as template. Don't mess with this file unless you know what you're doing.
    verbose : if True (default), prints some messages.

    A global xml namespace is set for QTI and the following global variables are created:

    qti_template : ElementTree
    qti_root : the root element of qti_template
    qti_template_upload_question : Element
    qti_template_MCQ : Element
    ns : string containing namespace for qti xml file
    nsp : as above, but wrapped in {}
    '''
    global ns
    global nsp
    global qti_template
    global qti_root
    global qti_template_upload_question
    global qti_template_MCQ
    global qti_template_reponse
    # First, we set the correct xml namespaces
    ns = "http://www.imsglobal.org/xsd/ims_qtiasiv1p2"
    nsp = '{'+ns+'}'
    ET.register_namespace('', ns)
    ET.register_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")
    qti_template = ET.parse(template_filename) # Load the template from file
    qti_root = qti_template.getroot() # the root of this tree
    for item in qti_root.findall(".//"+nsp+"item"): # Next, we extract templates for questions
        for l in item.findall(".//"+nsp+"qtimetadatafield"):
            if l.find(nsp+'fieldlabel').text == 'question_type':
                if l.find(nsp+'fieldentry').text == 'file_upload_question':
                    if verbose: print(f'Got the file upload question: {item.get("title")}')
                    qti_template_upload_question = deepcopy(item)
                if l.find(nsp+'fieldentry').text == 'multiple_choice_question':
                    if verbose: print(f'Got the multiple-choice question: {item.get("title")}')
                    qti_template_MCQ = deepcopy(item)
    # Now delete all items from the template, so what's left an empty assessment, ready for inserting new questions:
    for section in qti_root.findall(".//"+nsp+"section"):
        for item in section.findall(nsp+"item"):
            section.remove(item)
    qti_template_reponse = deepcopy(qti_template_MCQ.find(".//"+nsp+"response_label"))
    assessment = qti_root.find(".//"+nsp+"assessment")
    assessment.set('title', title)
    if ident is None:
        ident = 'g'+id_generator(size=30, chars='0123456789abcdef')
    assessment.set('ident', ident)
    return deepcopy(qti_template)

def qti_set_question_text(R, text):
    '''Given qti question R, changes the question text to text.'''
    R.find(".//"+nsp+"mattext").text = text

def qti_set_identifier(R, text):
    '''Given qti question R, changes the identifierref to text'''
    for l in R.findall(".//"+nsp+"qtimetadatafield"):
        if l.find(nsp+'fieldlabel').text == 'assessment_question_identifierref':
            l.find(nsp+'fieldentry').text = text

def qti_set_points(R, points):
    '''Given QTI question R, changes points to points.'''
    for l in R.findall(".//"+nsp+"qtimetadatafield"):
        if l.find(nsp+'fieldlabel').text == 'points_possible':
            l.find(nsp+'fieldentry').text = str(points)

def qti_file_upload_question_new():
    '''Returns a fresh copy of the file upload template'''
    return deepcopy(qti_template_upload_question)

def ET_file_upload_question(text='Question text',
                           a_q_id=None,
                           points=3,
                           ident=None,
                           title='Question 1'):
    '''Returns an ElementTree element containing a QTI file upload question. a_q_id and ident will be
    randomly generated unless given specific values'''
    Q = qti_file_upload_question_new() # create a new instance
    Q.set('title',title)
    if ident is None:
        ident = 'g'+id_generator(size=30, chars='0123456789abcdef')
    Q.set('ident', ident)
    qti_set_question_text(Q, text)
    if a_q_id is None:
        a_q_id = 'g'+id_generator(30)
    qti_set_identifier(Q, a_q_id)
    qti_set_points(Q, points)
    return Q

def qti_MCQ_new():
    '''Returns a fresh copy of the multiple-choice question template'''
    return deepcopy(qti_template_MCQ)


def ET_MCQ(text='Question text',
           a_q_id=None,
           points=1,
           ident=None,
           title='Question 1',
           answer='Correct answer',
           wrong_answers=['wrong answer 1', 'wrong answer 2', 'wrong answer 3'],
           none_of_these=True):
    '''Returns an ElementTree element containing a QTI multiple-choice question. a_q_id and ident will be
    randomly generated unless given specific values'''
    Q = qti_MCQ_new() # create a new instance
    Q.set('title',title)
    if ident is None:
        ident = 'g'+id_generator(size=30, chars='0123456789abcdef')
    Q.set('ident', ident)
    qti_set_question_text(Q, text)
    if a_q_id is None:
        a_q_id = 'g'+id_generator(30)
    qti_set_identifier(Q, a_q_id)
    qti_set_points(Q, points)
    answers = [answer]+wrong_answers
    if none_of_these:
        answers.append('None of these')
    # Now generate the original_answer_ids. I'm not sure what happens if there is a collision of these
    # among different questions... but at least make sure no collisions happen within a question
    options = len(answers)
    answer_ids = list({id_generator(size=1, chars='123456789')+id_generator(size=3, chars='0123456789')
                       for k in range(options+2)})[:options]
    # write the list of answer_ids to the right place
    for l in Q.findall(".//"+nsp+"qtimetadatafield"):
        if l.find(nsp+'fieldlabel').text == 'original_answer_ids':
            l.find(nsp+'fieldentry').text = ','.join(answer_ids)
    # delete response_labels from template:
    render_choice = Q.find(".//"+nsp+"render_choice")
    for response_label in render_choice.findall(nsp+"response_label"):
        render_choice.remove(response_label)
    # now insert the various choices
    for k, text in enumerate(answers):
        response = deepcopy(qti_template_reponse)
        response.set('ident', answer_ids[k])
        qti_set_question_text(response, text)
        render_choice.append(response)
    # Finally, tell it which response is the correct one
    varequal = Q.find(".//"+nsp+"varequal")
    varequal.text = answer_ids[0]
    return Q

def qti_insert_question(Q, T=None):
    '''Inserts question Q into a qti assessment T, which should be of type ElementTree.
    If T is None, then the global qti_template is used.
    Returns T.
    '''
    if T is None:
        T = qti_template
    R = T.getroot()
    section = R.find(".//"+nsp+"section")
    section.append(Q)
    return T

def save_qti(filename, T=None, verbose=False):
    '''Save the T to filename.
    T should be an ElementTree, not Element. Default: qti_template.
    filename should be the filename without extension.
    The result is two files: filename.xml and filename.zip.'''
    if T is None:
        T = qti_template
    T.write(filename+'.xml', encoding='UTF-8', xml_declaration=True)
    if verbose: print(f'Created {filename}.xml')
    with ZipFile(filename+'.zip', 'w') as zipobj:
        zipobj.write(filename+'.xml')
    if verbose: print(f'Created {filename}.zip - You can upload this file to Canvas.')

# The next bits of code are for type-setting mathematical stuff

def nicify(s):
    '''Performs some simplification of LaTeX code in s, only suitable in some cases.'''
    s = s.replace(r"\left(","(")
    s = s.replace(r"\right)",")")
    s = s.replace("y(x)","y")
    s = s.replace("log","ln")
    return(s)


def nicify0(s):
    '''Replaces "log" by "ln" and "y(x)" by "y" for DE-type questions.'''
    s = s.replace(r"y\left(x\right)","y")
    s = s.replace("log","ln")
    return(s)

def plus(x):
    '''Returns the LaTeX string "+x", where x is a number, unless x = 1 (resp. -1),
    in which case it returns "+" (resp. "-").
    This is useful when x is meant to be a coefficient of something
    '''
    if x == 1:
        return("+")
    if x == -1:
        return("-")
    if x >= 0:
        return("+"+latex(x))
    else:
        return("-"+latex(-x))

def pplus(x):
    '''Returns the LaTeX string "+x", unless x is negative, in which case it returns "-|x|".'''
    if x < 0:
        return("-"+latex(-x))
    else:
        return("+"+latex(x))



def suppress1(x):
    '''Returns the LaTeX string "x", where x is a number, unless x = 1 (resp. -1),
    in which case it returns "+" (resp. "-").
    This is useful when x is a coefficient of something.
    '''
    if x == 1:
        return("")
    if x == -1:
        return("-")
    else:
        return(latex(x))

def Taylor(f, a=0, n=10):
    '''Returns a latex string for the degree n Taylor polynomial of f about x=a.'''
    # produces the degree n Taylor polynomial of f about x=a, returns it as a latex string
    # SAGE's built-in Taylor expansion is often simplified in annoying ways
    x=var('x')
    s=''
    if a==0:
        for i in range(n+1):
            c = diff(f,x,i)(a)/factorial(i)
            sc = re.sub('x','',latex(c*x))  # encapsulate c in brackets if necessary
            if c!=0:
                if i==0:
                    if c==1:
                        s=latex(1)
                    elif c==-1:
                        s=latex(-1)
                    else:
                        s=sc
                elif i==1:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'x'
                    elif c==-1:
                        s=s+'-x'
                    elif c<0:
                        s=s+sc+'x'
                    else:
                        if len(s)>0:
                            s=s+'+'
                        s=s+sc+'x'
                else:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'x^{'+latex(i)+'}'
                    elif c==-1:
                        s=s+'-x^{'+latex(i)+'}'
                    else:
                        if (len(s)>0) & (sc[0]!='-'):
                            s=s+'+'
                        s=s+sc+'x^{'+latex(i)+'}'
    elif a>0:
        for i in range(n+1):
            c = diff(f,x,i)(a)/factorial(i)
            sc = re.sub('x','',latex(c*x))  # encapsulate c in brackets if necessary
            if c!=0:
                if i==0:
                    if c==1:
                        s=latex(1)
                    elif c==-1:
                        s=latex(-1)
                    else:
                        s=sc
                elif i==1:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'(x-'+latex(a)+')'
                    elif c==-1:
                        s=s+'-(x-'+latex(a)+')'
                    else:
                        if (len(s)>0) & (sc[0]!='-'):
                            s=s+'+'
                        s=s+sc+'(x-'+latex(a)+')'
                else:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'(x-'+latex(a)+')^{'+latex(i)+'}'
                    elif c==-1:
                        s=s+'-(x-'+latex(a)+')^{'+latex(i)+'}'
                    else:
                        if (len(s)>0) & (sc[0]!='-'):
                            s=s+'+'
                        s=s+sc+'(x-'+latex(a)+')^{'+latex(i)+'}'
    else: # a<0
        for i in range(n+1):
            c = diff(f,x,i)(a)/factorial(i)
            sc = re.sub('x','',latex(c*x))  # encapsulate c in brackets if necessary
            if c!=0:
                if i==0:
                    if c==1:
                        s=latex(1)
                    elif c==-1:
                        s=latex(-1)
                    else:
                        s=sc
                elif i==1:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'(x+'+latex(-a)+')'
                    elif c==-1:
                        s=s+'-(x+'+latex(-a)+')'
                    else:
                        if (len(s)>0) & (sc[0]!='-'):
                            s=s+'+'
                        s=s+sc+'(x+'+latex(-a)+')'
                else:
                    if c==1:
                        if len(s)>0:
                            s=s+'+'
                        s=s+'(x+'+latex(-a)+')^{'+latex(i)+'}'
                    elif c==-1:
                        s=s+'-(x+'+latex(-a)+')^{'+latex(i)+'}'
                    else:
                        if (len(s)>0) & (sc[0]!='-'):
                            s=s+'+'
                        s=s+sc+'(x+'+latex(-a)+')^{'+latex(i)+'}'
    return(s)


def scramble(A,c=3):
    """Returns the matrix A with some random row operations performed on it."""
    rows=A.dimensions()[0]
    for i in range(rows):
        for j in range(i):
            A.add_multiple_of_row(i,j,randint(-c,c))
    return(A)

def scramble_full(A,c=3):
    """Returns the matrix A with some more random row operations performed on it."""
    rows=A.dimensions()[0]
    for i in range(rows):
        for j in range(rows):
            if i!=j:
                A.add_multiple_of_row(i,j,randint(-c,c))
    return(A)

def tootrivial(A):
    """Returns true if A has two equal rows, a row equal to -(another row) or a row of zeroes."""
    [rows,cols]=A.dimensions()
    zero=[0 for i in range(cols)]
    for i in range(rows):
        if list(A.row(i))==zero:
            #print("Row %s is zero"%str(i))
            return true
        for j in range(i):
            if (A.row(i)==A.row(j))|(A.row(i)==-1*A.row(j)):
                #print("Rows %s and %s are equal"%(i,j))
                return true
    return false

def latexdet(A):
    """Returns a LaTeX string for the determinant of A using vertical bars."""
    s=latex(A).replace("\\left(","\\left|")
    s=s.replace("\\right)","\\right|")
    return(s)


class MATHJAX():
    '''Takes an HTML formatted string with embedded LaTeX and typesets it. By Bjoern Rueffer'''
    def __init__(self,s):
        self.s = s
    def _repr_html_(self):
        '''this is used by display() / show() in your jupyter notebook'''
        return '''
        <div>
        <script type="text/javascript" async="" src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML"></script>
        </div>''' + self.s
    def __str__(self):
        '''this is used by print() and str()'''
        return(self._repr_html_())



class linear_system(object):
    """This class defines a system of linear equations by its r x (c+1) augmented matrix.

    The methods allow us to nicely typeset the equations and the augmented matrix.

    To Do:
        - Typeset equations nicely in an array with variables lined up
         """
    def __init__(self,C,varnames):
        """C is an r x (c+1) matrix; varnames is a list of c names for the variables"""
        self.C = C
        self.r = C.dimensions()[0]
        self.c = C.dimensions()[1]-1
        if len(varnames) != self.c:
            raise ValueError("Expected %s variables, but received %s"%(str(self.c),str(len(varnames))))
        self.X = var(varnames) # this is now a list of c variables
        self.eqs = []  # next, we create a system of symbolic equations
        for i in range(self.r):
            lhs = 0
            for j in range(self.c):
                lhs = lhs + self.C[i,j]*self.X[j]
            self.eqs.append(lhs == self.C[i,self.c])
        #self.sol = solve(self.eqs,self.X,solution_dict=true)
        self.A = self.C.matrix_from_columns(range(self.c))  # coefficient matrix
        self.b = self.C.matrix_from_columns([self.c])  # last column = RHS of equations, so system is Ax=b
        self.V = self.A.right_kernel_matrix().rows() # basis of free part of solution



    def __repr__(self):
        return "Linear system defined by \n"+str(self.C)

    def latex_eqs(self):
        """Return LaTeX code for the system of equations, using \\align.
        In future, I'd like to implement nicer typesetting in an array."""
        return("\\begin{align*}\n"\
               +"\\\\ \n".join([latex(eq.left_hand_side())+"&="+latex(eq.right_hand_side()) for eq in self.eqs])+\
              "\n\\end{align*}")

    def latex_coeff_matrix(self):
        """Return LaTeX code for the coefficient matrix. Or just use latex(self.A)..."""
        return("\\left[\\begin{array}{"+"".join(["r" for i in range(self.c)])+"}\n"+\
               "\\\\ \n".join([" & ".join([latex(self.C[i,j]) for j in range(self.c+1)]) for i in range(self.r)])+\
               "\n\\end{array}\\right]"
               )

    def latex_augmented_matrix(self):
        """Return LaTeX code for the agumented array."""
        return("\\left[\\begin{array}{"+"".join(["r" for i in range(self.c)])+"|r}\n"+\
               "\\\\ \n".join([" & ".join([latex(self.A[i,j]) for j in range(self.c)]) for i in range(self.r)])+\
               "\n\\end{array}\\right]"
              )

    def latex_sol(self):
        """Return LaTeX code for solution set of system"""
        self.num_parameters = len(self.V) # number of free parameters in solution
        if self.num_parameters <= 1:
            self.T = var(["t"])  # name of one free parameter
        else:
            self.T = var(["t"+str(i+1) for i in range(self.num_parameters)]) # names for free parameters
        try:
            self.v0 = vector(self.A.solve_right(self.b)) # a particular solution - if it exists
        except:
            self.v0 = none
            return("\\{\\}")   # no solutions
        s = "\\{"+latex(self.v0)
        if self.num_parameters > 0:
            s = s+"+"+" + ".join([latex(self.T[i])+latex(self.V[i]) for i in range(self.num_parameters)])
            s = s+", \\;"+", ".join([latex(self.T[i]) for i in range(self.num_parameters)])+" \\in \\mathbb{R}"
        s = s+"\\}"
        return(s)

class Question_Written(object):
    '''This is a written question.

    The most important methods are:
      self.q_text()   which returns the question as a string
      self.sol_text()   which returns the full solution as a string

    For backward compatibility, these methods also write their output to
    the attributes self.question_text and self.solution_text, respectively.
    The motivation for this slight change is to be able to update the variant
    number after initialising the question.

    It also contains summary data about the question to be included as a row in a LaTeX table of questions:
      self.table_header contains the headings for a table of question variants (e.g. question, answer).
      self.table_row contains the entries of a row containing this info.

    Various methods display this data, save the marking scheme to a .tex file, etc.

    To do:
      Add images to the questions.
    '''
    question_type = 'WAQ'
    points = 0
    variant_number = 0
    question_text = "there is no question text yet"
    question_text_basic = "there is no question text yet"
    solution_text = "no solution to no question"
    rubric = r"""
\noindent{\bf Marking Scheme:}
\begin{small}
\begin{itemize}
\item 1 mark: The student demonstrates a partial understanding of how to do the problem.
\item 2 marks: The student demonstrates a good understanding of how to do the problem \\ (some minor errors permitted).
\item 3 marks: The student demonstrates a good understanding and obtains the correct answer.
\end{itemize}
\end{small}"""
    table_row = []
    table_header = []

#     def __init__(self):
#         self.points = 0
#         self.variant_number = 0
#         self.question_text = "there is no question text yet"
#         self.question_text_basic = "there is no question text yet"   # this can be question text without variant number
#         self.solution_text = "no solution to no question"
#         self.rubric = r"""
# \noindent{\bf Marking Scheme:}
# \begin{small}
# \begin{itemize}
#   \item 1 mark: The student demonstrates a partial understanding of how to do the problem.
#   \item 2 marks: The student demonstrates a good understanding of how to do the problem \\ (some minor errors permitted).
#   \item 3 marks: The student demonstrates a good understanding and obtains the correct answer.
# \end{itemize}
# \end{small}"""
#         self.table_row = []
#         self.table_header = []

    def q_text(self): # these can be rewritten when defining new questions
        self.update_variant_number()
        return self.question_text

    def sol_text(self):
        return self.solution_text

    def update_variant_number(self, variant_number=None):
        '''Change the variant number, update question text accordingly'''
        if variant_number != None:
            self.variant_number = variant_number
        self.question_text = self.question_text_basic + "<br>[For office use only: V" + str(self.variant_number)+"]"

    def qti(self, variant_number=None, points=3, title=None):
        '''Return and ElementTree element representing this question, ready for inserting into a QTI assessment.
        if variant_number is None, the question's own variant number is used.'''
        if variant_number is not None:
            self.update_variant_number(variant_number)
        if title is None:
            title = f'Question {self.variant_number}'
        return ET_file_upload_question(text=self.q_text(), points=points, title=title)

#     def __repr__(self):
#         return "An unspecified written-answer question worth %s points"%self.points

    def make_BB_row(self):
        '''Returns a row for writing self to a Blackboard file.
        This code owes much to Bjoern Rueffer.'''
        self.BB_question_text = self.q_text()
        self.BB_question_text = re.sub(r'\$\$(.*?)\$\$',r'\\[\1\\]',self.BB_question_text)
        self.BB_question_text = re.sub(r'\$(.*?)\$',r'\\(\1\\)',self.BB_question_text)
        self.BB_question_text = re.sub(r'\\dfrac\b',r'\\frac',self.BB_question_text)
        self.BB_question_text = re.sub('[\n ]+',' ',self.BB_question_text)
        return("FIL\t"+self.BB_question_text+"\n")


    def write_BB_row(self, f):  #f is a file that's already been opened for writing
        '''Writes the question in one line to file f (assumed to be open and writable) in the correct format for BlackBoard.
        '''
        f.write(self.make_BB_row())


    def __repr__(self):
        return(self.q_text())

    def latex_question_text(self):
        '''Returns self.question_text with "<br>" replaced by "\n\n".'''
        return(self.q_text().replace("<br>","\n\n"))

    def latex_solution_page(self,var_number=-1):
        '''Returns a page for the marking scheme; var_number is an optional variant number '''
        if var_number==-1:
            var_number=self.variant_number  # i can be changed post-hoc in case variant_number wasn't initially supplied
        s = "\\newpage\n\\section{Variant "+str(var_number)+"}\n\\label{v"+str(var_number)+"}\n\n"+\
        self.latex_question_text()+"\n\\medskip\n\n"+r"\noindent{\bf Solution.}"+"\n\n"+self.sol_text()+"\n\\medskip\n\n"+self.rubric
        return(s)

    def test_solution_page(self,filename="test.tex",var_number=-1):
        '''Writes the solution page to a ready-to-compile LaTex file for testing'''
        with open(filename,'w') as f:
            f.write(r"\documentclass{article}"+"\n"+r"\usepackage{amssymb,amsmath,hyperref,a4wide}"+"\n\n"+r"\begin{document}"+"\n"+\
            self.latex_solution_page(var_number=var_number)+"\n"+r"\end{document}")

    def _repr_html_(self):
        return(self.q_text())


class Question_MCQ(object):
    """
    This class defines a multiple choice question.

    ATTRIBUTES:
        points : int
        answer : str
        wrong answers : List of str, most methods assume that there are exactly 3 wrong answers
               - I hope to change this in future
        question_text : str
        answer_shuffle : some permutation of [0,1,2,3] - used to print the answers in shuffled form
        answer_index : the index of the correct answer in the shuffled list - it's the index of 0 in answer_shuffle
        shuffle_seed : the random seed used for shuffling; intialised as randint(1,10000), optionally set in method shuffle()

        To do: improve shuffling, so it can take any number of wrong answers.


    """
    question_type = 'MCQ'
    points = 0
    answer = ""
    wrong_answers = []
    question_text = "An empty question"
    answer_shuffle = [0,1,2,3]
    answer_index = 0
    shuffle_seed = 0
    table_row = []   # won't use this, but the selection_wizard wants to see it
    table_header = [] # ditto
    # def __init__(self):
    #     self.points = 0
    #     self.answer = ""
    #     self.wrong_answers = []
    #     self.question_text = "An empty question"
    #     self.answer_shuffle = [0,1,2,3]
    #     self.answer_index = 0
    #     self.shuffle_seed = randint(1,10000)


    def __repr__(self):
        return(self.question_text)

    def q_text(self): # these can be rewritten when defining new questions
        return self.question_text

    def update_variant_number(self, variant_number=None):
        '''Change the variant number'''
        if variant_number != None:
            self.variant_number = variant_number

    def qti(self, variant_number=None, points=1, title=None):
        '''Return and ElementTree element representing this question, ready for inserting into a QTI assessment.
        if variant_number is None, the question's own variant number is used.'''
        if variant_number is not None:
            self.variant_number = variant_number
        if title is None:
            title = f'Question {self.variant_number}'
        return ET_MCQ(text=re.sub(r'\$(.*?)\$',r'\\(\1\\)',self.question_text), points=points, title=title, answer=self.answer, wrong_answers=self.wrong_answers)


    def make_BB_row(self):
        '''Converts the question and answers into a a tuple of the format
        (MC, question, random_answer1, "correct/incorrect", ..., random_answer4, "correct/incorrect", "None of the others", "incorrect").

        The shuffling of the answers and the insertion of the last option is automatic and different
        in each invocation of this function. All formulas are escaped to play nicely with MathJax. All
        newlines are replaced with normal spaces, to comply with the format requirements of Blackboard.

        Code written by Bjoern Rueffer'''
        row = [self.question_text,self.answer,self.wrong_answers[0],self.wrong_answers[1],self.wrong_answers[2]]
        row = map(lambda s: re.sub(r'\$\$(.*?)\$\$',r'\\[\1\\]',s), row)
        row = map(lambda s: re.sub(r'\$(.*?)\$',r'\\(\1\\)',s), row)
        #row = map(lambda s: re.sub(r'\\displaystyle\b',r' ',s), row)
        row = map(lambda s: re.sub(r'\\dfrac\b',r'\\frac',s), row)
        row = map(lambda s: re.sub('[\n ]+',' ',s), row)
        question, *answers = tuple(row)
        answers = list(zip(answers, ('correct',*('incorrect',)*3)))
        py_random.shuffle(answers)
        answers = itertools.chain(*answers)
        answers = list(answers)
        return ('MC',question, *answers, 'None of the others', 'incorrect')

    def write_BB_row(self, f):  #f is a file that's already been opened for writing
        '''Writes the question in one line to file f (assumed to be open and writable) in the correct format for BlackBoard'''
        f.write("\t".join(self.make_BB_row())+"\n")

    def latex_sorted(self):
        '''Returns LaTex code that typsets the question and answers. Correct answer listed first.'''
        return self.question_text+"\n\\begin{enumerate}\n  \\item %s \n  \\item %s \n"%(self.answer,self.wrong_answers[0])+\
    "  \\item %s \n  \\item %s \n  \\item None of the others \n\\end{enumerate}"%(self.wrong_answers[1], self.wrong_answers[2])

    def shuffle(self, s=0):
        '''Shuffles the four answers, using the random seed self.shuffle_seed, which can be set by the optional parameter s.'''
        if s!=0:
            self.shuffle_seed = s
        else:
            self.shuffle_seed = randint(1,10000)
        self.answer_shuffle = [0,1,2,3]
        with seed(self.shuffle_seed):
            shuffle(self.answer_shuffle)
        i=1
        for a in self.answer_shuffle:
            if a==0: self.answer_index = i
            i+=1

    def latex_shuffled(self):
        '''Returns LaTex code that typsets the question and answers.
        Answers are listed in the order determined by self.answer_shuffle'''
        answers = [self.answer]+self.wrong_answers
        answers = [answers[x] for x in self.answer_shuffle]
        return self.question_text+"\n\\begin{enumerate}\n  \\item %s \n  \\item %s \n"%(answers[0],answers[1])+\
    "  \\item %s \n  \\item %s \n  \\item None of the others \n\\end{enumerate}"%(answers[2], answers[3])

    def has_distinct_answers(self):
        '''Returns true if all answers are distinct.'''
        answers = [self.answer]+self.wrong_answers
        return len(answers)==len(set(answers))

    def _repr_html_(self):
        s=self.question_text+r"<br><ol>"+\
        "\n".join([r"<li>"+a+r"</li>" for a in [self.answer]+self.wrong_answers+["None of these"]])+\
        r"</ol>"
        return(s)

def SaveToBBfile(L, filename):
    '''Saves a list L of questions to a file for uploading to Blackboard.'''
    with open(filename,'w') as f:
        for Q in L:
            Q.write_BB_row(f)

def SaveToQtiFile(L, filename, title='Squid-made question pool', make_variant_numbers=True, verbose=True):
    '''Saves a list L of Squid questions to a qti file for uploading to canvas.
    filename should *exclude* the file extension.'''
    T = initialise_qti(title=title, verbose=verbose)
    if make_variant_numbers:
        for k,Q in enumerate(L):
            Q.update_variant_number(k+1)
    for Q in L:
        qti_insert_question(Q.qti(), T)
    save_qti(filename=filename, T=T, verbose=verbose)


def PrintMarkingScheme(L, course="MATH1120 2020 S2 ", title="", print_table=true, array_stretch=1):
    '''Prints a marking scheme for the list L of written-answer questions'''
    print(r"\documentclass{article}")
    print(r"\usepackage{amssymb,amsmath,hyperref,a4wide}")
    print()
    print(r"\begin{document}")
    if array_stretch != 1:
        print(r"\renewcommand{\arraystretch}{"+str(array_stretch)+"}")
    print(r"\setcounter{page}{0}")
    print(course+title)  # e.g. "MATH1120 - 2020 - Workshop Week 3"
    print()
    print(r"Marking scheme for written-answer question")
    print()
    if print_table:
        print(r"\setcounter{section}{-1}")
        print(r"\section{Variant List}")
        print()
        cols = len(L[0].table_row)  # number of columns, excluding first column
        print(r"\medskip")
        print(r"\begin{tabular}{|l|"+"".join(["l|" for i in range(cols)])+"}")
        print(r"\hline")
        print(r"Variant & "+" & ".join(L[0].table_header)+r"\\ \hline")
        i=0
        for Q in L:
            i+=1
            if Q.variant_number>0:
                j=Q.variant_number
            else:
                j=i
            print(r"\hyperref[v"+str(j)+r"]{Variant "+str(j)+r"} & "+" & ".join(Q.table_row)+r"\\ \hline")
        print(r"\end{tabular}")
    print()
    print(r"\medskip")
    print(r"\begin{small}")
    print(r"\begin{itemize}")
    print(r"  \item 1 mark: The student demonstrates a partial understanding of how to do the problem.")
    print(r"  \item 2 marks: The student demonstrates a good understanding of how to do the problem \\ (some minor errors permitted).")
    print(r"  \item 3 marks: The student demonstrates a good understanding and obtains the correct answer.")
    print(r"\end{itemize}")
    print(r"\end{small}")

    i=0
    for Q in L:
        i+=1
        if Q.variant_number>0:
            print(Q.latex_solution_page())
        else:
            print(Q.latex_solution_page(i))


    print(r"\end{document}")


def TypesetMarkingScheme(L, course="MATH1120 2020 S2 ", title="", print_table=true, array_stretch=1, two_cols=False):
    '''Returns a marking scheme for the list L of written-answer questions'''
    s=r"\documentclass{article}"+"\n"+\
    r"\usepackage{amssymb,amsmath,hyperref,a4wide}"+"\n\n"+\
    r"\begin{document}"
    if array_stretch != 1:
        s+=r"\renewcommand{\arraystretch}{"+str(array_stretch)+"}"
    s+=r"\setcounter{page}{0}"+"\n"+\
    r"{\Large "+course+" "+title+r"}"+"\n\n"+\
    r"Marking scheme for written-answer question"+"\n\n"

    if print_table:
        s+=r"\setcounter{section}{-1}"+"\n\n"+\
        r"\section{Variant List}"+"\n\n"
        cols = len(L[0].table_row)  # number of columns, excluding first column
        s+=r"\medskip"+"\n"
        if two_cols:  # the table would be too long, make two entries per table row
            s=s+r"\begin{tabular}{|l|"+"".join(["l|" for i in range(cols)])+"|l|"+"".join(["l|" for i in range(cols)])+"}"+\
            r"\hline"+"\n"+\
            r"Variant & "+" & ".join(L[0].table_header)+ r"& Variant & "+" & ".join(L[0].table_header)+ r"\\ \hline"+"\n"
            for i in range(0,len(L),2):
                Q = L[i]
                if Q.variant_number>0:
                    j = Q.variant_number
                else:
                    j = i
                s += r"\hyperref[v"+str(j)+r"]{Variant "+str(j)+r"} & "+" & ".join(Q.table_row)
                if i < len(L)-1:
                    Q = L[i+1]
                    if Q.variant_number>0:
                        j = Q.variant_number
                    else:
                        j = i+1
                    s += r"& \hyperref[v"+str(j)+r"]{Variant "+str(j)+r"} & "+" & ".join(Q.table_row)+r"\\ \hline"+"\n"
                else:
                    s += "& & "+"&".join(' ' for entry in Q.table_row)+r"\\ \hline"+"\n"
        else: # make a single table
            s=s+r"\begin{tabular}{|l|"+"".join(["l|" for i in range(cols)])+'}\n'+\
            r"\hline"+"\n"+\
            r"Variant & "+" & ".join(L[0].table_header)+r"\\ \hline"+"\n"
            i=0
            for Q in L:
                i+=1
                if Q.variant_number>0:
                    j=Q.variant_number
                else:
                    j=i
                s+=r"\hyperref[v"+str(j)+r"]{Variant "+str(j)+r"} & "+" & ".join(Q.table_row)+r"\\ \hline"+"\n"
        s+=r"\end{tabular}"+"\n\n"
    s+=r"\medskip"+"\n"
    s+=L[0].rubric+"\n\n"
    i=0
    for Q in L:
        i+=1
        if Q.variant_number>0:
            s+=Q.latex_solution_page()+"\n\n"
        else:
            s+=Q.latex_solution_page(i)+"\n\n"


    s+=r"\end{document}"

    return(s)


def SaveMarkingScheme(L, filename, course="MATH1120 2020 S2 ", title="", print_table=true, array_stretch=1, two_cols=False):
    '''Writes the marking scheme for the list L of questions to filename.'''
    with open(filename,'w') as f:
        f.write(TypesetMarkingScheme(L,course=course,
                                    title=title,
                                    print_table=print_table,
                                    array_stretch=array_stretch,
                                    two_cols=two_cols))

# Lastly, here's the code for a variant selection wizard. You store a bunch of variants of a question in a listed
# and pass this list to QuestionPool. Then run the selection_wizard() to select a subset of variants and write it
# to files for BlackBoard or Canvas, and write marking schemes (for written-answer questions.)

class QuestionPool(object):

    def __init__(self,
                 L=[],
                 course_name='MATH1120-S2-2021',
                 quiz_name = 'W10',
                 question_name='LA2_LinearIndep_written'):

        self.L = L    # list of all question sent to pool
        self.selected = []  # list of selected questions
        self.course_name = course_name
        self.quiz_name = quiz_name
        self.question_name = question_name

    def selection_wizard(self):
        '''Runs the selection Wizard to select questions from self.L, write to file, etc.
        Here L is a list of Squid questions, i.e. either Question_written or Question_MCQ.
        Ideally, all questions should be of the same class.'''
        b = 0
        self.L_selected = []
        items = [widgets.ToggleButton(description="variant "+str(i), button_style='') for i in range(len(self.L))]
        master = widgets.VBox([widgets.HBox(
            [items[i], widgets.HTMLMath(value="   :   ".join([a for a in L[i].table_row]))]) for i in range(len(self.L))])
        display(master)
        # widgets.Label(value=str([c.value for c in items]))
        out = widgets.Output(layout={'border': '1px solid black'}, description='Status:')

        Button_Count = widgets.Button(description="Count: ")
        def Count(b):
            count=0
            for c in items:
                if c.value:
                    count += 1
            Button_Count.description = "Count: "+str(count)
        Button_Count.on_click(Count)

        def TB_on_value_change(change):
            Count(b)
            tb = change['owner']
            if tb.value:
                tb.icon = 'check'
            else:
                tb.icon = ''

        # The following might be reducing performance:
#         for tb in items:
#             tb.observe(TB_on_value_change, names='value')

        Button_SelectAll = widgets.Button(description="Select All")
        def SelectAll(b):
            for c in items:
                c.value = true
            Button_Count.description = "Count: "+str(len(self.L))
        Button_SelectAll.on_click(SelectAll)

        Button_SelectNone = widgets.Button(description="Select None")
        def SelectNone(b):
            for c in items:
                c.value = false
            Button_Count.description = "Count: 0"
        Button_SelectNone.on_click(SelectNone)


        Button_MakeSelection = widgets.Button(description="Make Selection")
        def MakeSelection(b):
            self.selected = []
            count = 0
            for i in range(len(self.L)):
                if items[i].value:
                    count += 1
                    Q = self.L[i]
                    Q.update_variant_number(count)
                    self.selected.append(Q)

            Button_Count.description="Count: "+str(count)
            with out:
                print("Selected %d Questions:"%count, [i for i in range(len(self.L)) if items[i].value])
#             return(selection)
        Button_MakeSelection.on_click(MakeSelection)

        Button_ClearOutput = widgets.Button(description="Clear Output")
        def ClearOutput(b):
            out.clear_output()
        Button_ClearOutput.on_click(ClearOutput)

        MarkingSchemeFilename = widgets.Text(value=self.course_name+'-'+self.quiz_name+"-MarkingScheme.tex",
                                             description='Filename:')

        MarkingSchemeArrayStretch = widgets.FloatText(value=1.5,step=0.1, description='Baseline_stretch:')

        BBFilename = widgets.Text(value=self.question_name+".txt", description='BB filename:')

        QTIFilename = widgets.Text(value=self.question_name, description='QTI filename:', tooltip='without file extension')

        QTITitle = widgets.Text(value=self.question_name, description="QTI title:")

        Path = widgets.Text(value="",description="File path:")

        CourseName = widgets.Text(value=self.course_name, description="Course:")

        QuizTitle = widgets.Text(value=self.quiz_name, description="Quiz:")

        MSPrintTable = widgets.Checkbox(value=true, description="Print table:")

        MakeTwoColumn = widgets.ToggleButton(value=False, description="2 column table:")

        Button_SaveMarkingScheme = widgets.Button(description="Save Marking Scheme")
        def SaveMarkingSchemeB(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            if Path.value != "":
                fn = MarkingSchemeFilename.value
                # fn=Path.value+"\\"+MarkingSchemeFilename.value
            else:
                fn = MarkingSchemeFilename.value
            SaveMarkingScheme(self.selected, filename=fn, course=CourseName.value, title=QuizTitle.value,
                              print_table=MSPrintTable.value, array_stretch=MarkingSchemeArrayStretch.value,
                              two_cols=MakeTwoColumn.value)
            with out:
                print('Marking scheme for variants', [i for i in range(len(self.L)) if items[i].value],' saved to ',fn)
        Button_SaveMarkingScheme.on_click(SaveMarkingSchemeB)

        Button_PrintMarkingScheme = widgets.Button(description="Print Marking Scheme")
        def PrintMarkingSchemeB(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            with out:
                print('Marking Scheme:')
                print()
                print(TypesetMarkingScheme(self.selected, course=CourseName.value, title=QuizTitle.value,
                                           array_stretch=MarkingSchemeArrayStretch.value,
                                           two_cols=MakeTwoColumn.value))
        Button_PrintMarkingScheme.on_click(PrintMarkingSchemeB)

        Button_SaveBB = widgets.Button(description="Save Blackboard file")
        def SaveBBFile(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            if Path!="":
                fn = BBFilename.value
                # fn=Path.value+"\\"+BBFilename.value    # This doesn't work for some reason
            else:
                fn = BBFilename.value
            SaveToBBfile(self.selected, fn)
            with out:
                print('BB entries for variants',[i for i in range(len(self.L)) if items[i].value],' saved to ',fn)
        Button_SaveBB.on_click(SaveBBFile)

        Button_SaveQTI = widgets.Button(description="Save QTI file")
        def SaveQTIFile(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            if Path!="":
                # fn=Path.value+"\\"+QTIFilename.value
                fn = QTIFilename.value
            else:
                fn = QTIFilename.value
            SaveToQtiFile(self.selected, fn, title=QTITitle.value, verbose=False)
            with out:
                print(f'Variants {[i for i in range(len(self.L)) if items[i].value]} saved to {fn}.zip')
        Button_SaveQTI.on_click(SaveQTIFile)

        Button_PreviewQuestions = widgets.Button(description="Preview Selected Questions")
        def PreviewQuestions(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            with out:
                for Q in self.selected:
                    display(Q)
        Button_PreviewQuestions.on_click(PreviewQuestions)

        Button_PrintBBRows = widgets.Button(description="Print BB Rows")
        def PrintBBRows(b):
            MakeSelection(b)
            if len(self.selected) == 0:
                with out:
                    print('No variants selected!')
                return
            with out:
                for Q in self.selected:
                    print(Q.make_BB_row())
        Button_PrintBBRows.on_click(PrintBBRows)

        SelectRange = widgets.IntRangeSlider(
            value=[0, len(L)-1],
            min=0,
            max=len(L)-1,
            step=1,
            description='Select range:',
            disabled=False,
            continuous_update=False,
            orientation='horizontal',
            readout=True,
            readout_format='d',
        )

        Button_SelectAdd = widgets.Button(description="Add")
        def SelectAdd(b):
            for i in range(SelectRange.value[0],SelectRange.value[1]+1):
                items[i].value=true
            Count(b)
        Button_SelectAdd.on_click(SelectAdd)

        Button_SelectRemove = widgets.Button(description="Remove")
        def SelectRemove(b):
            for i in range(SelectRange.value[0],SelectRange.value[1]+1):
                items[i].value=false
            Count(b)
        Button_SelectRemove.on_click(SelectRemove)

        Button_SelectInvert = widgets.Button(description="Invert")
        def SelectInvert(b):
            for i in range(SelectRange.value[0],SelectRange.value[1]+1):
                items[i].value=not items[i].value
            Count(b)
        Button_SelectInvert.on_click(SelectInvert)

        Selector_MasterMode = widgets.Dropdown(options=['Table Row','Question Preview'], value='Table Row',
                                             description='Display Mode')


        def on_change_master_mode(change):
            if change['new'] == 'Table Row':
                for i in range(len(self.L)):
                    master.children[i].children[1].value="   :   ".join([a for a in self.L[i].table_row])
            elif change['new'] == 'Question Preview':
                for i in range(len(self.L)):
                    master.children[i].children[1].value=L[i].q_text()
            else:
                for i in range(len(self.L)):
                    master.children[i].children[1].value=L[i].q_text()+'<br>'+\
                    '<ol><li>'+L[i].answer+' (correct)'+\
                    '</li><li>'+'</li><li>'.join(L[i].wrong_answers)+'</li></ol>'
        Selector_MasterMode.observe(on_change_master_mode, names="value")


        tab=widgets.Tab()
        tab.children=[widgets.HBox([SelectRange,
                                    Button_SelectAdd,
                                    Button_SelectRemove,
                                    Button_SelectInvert
                                   ]),
                      widgets.VBox([MarkingSchemeFilename,
                                    QuizTitle,
                                    MSPrintTable,
                                    MarkingSchemeArrayStretch,
                                    widgets.HBox([Button_PrintMarkingScheme,Button_SaveMarkingScheme, MakeTwoColumn])
                                   ]),
                      widgets.VBox([widgets.HBox([QTIFilename, QTITitle]),
                                   Button_SaveQTI
                                   ]),
                      widgets.VBox([BBFilename,
                                    widgets.HBox([Button_PrintBBRows,Button_SaveBB])
                                   ]),
                      widgets.VBox([CourseName,
                                    QuizTitle,
                                    Path,
                                    Selector_MasterMode,
                                   ])
                     ]
        tab.set_title(index=0, title='Selection')
        tab.set_title(index=1, title='Marking scheme')
        tab.set_title(index=2, title='QTI (Canvas)')
        tab.set_title(index=3, title='Blackboard')
        tab.set_title(index=4, title='Options')

        display(widgets.HBox([Button_Count, Button_SelectAll, Button_SelectNone,
                              Button_MakeSelection, Button_PreviewQuestions, Button_ClearOutput]))
        display(tab)

        display(out)
        display(Button_ClearOutput)

        if L[0].question_type == 'MCQ': # use Question Preview mode for MCQs
        # if L[0].__class__.__bases__[0] is Question_MCQ:       # use Question Preview mode for MCQs
            Selector_MasterMode.value='Question Preview'
            Selector_MasterMode.options=['Question Preview', 'Question & Answers']
            Button_SaveMarkingScheme.disabled=True
            Button_PrintMarkingScheme.disabled=True
            for i in range(len(self.L)):
                    master.children[i].children[1].value=L[i].q_text()
