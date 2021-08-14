/*
 * g++ -o btree binary_tree.cpp
 */

#include <iostream>

struct BinaryTreeNode {
    int value;
    struct BinaryTreeNode *leftNode;
    struct BinaryTreeNode *rightNode;
};

void preorder(BinaryTreeNode *root)
{
    if (root == NULL) {
        return;
    }
    std::cout << root->value << " ";
    preorder(root->leftNode);
    preorder(root->rightNode);
}

void inorder(BinaryTreeNode *root)
{
    if (root == NULL) {
        return;
    }

    inorder(root->leftNode);
    std::cout << root->value << " ";
    inorder(root->rightNode);
}

void postorder(BinaryTreeNode *root)
{
    if (root == NULL) {
        return;
    }
    postorder(root->leftNode);
    postorder(root->rightNode);
    std::cout << root->value << " ";
}

/*
 *      A
 *     / \
 *    B   C
 *   / \  /
 *  D  E F
 */
int main()
{
    BinaryTreeNode D4 = {4, NULL, NULL};
    BinaryTreeNode E5 = {5, NULL, NULL};
    BinaryTreeNode F6 = {6, NULL, NULL};
    BinaryTreeNode B2 = {2, &D4, &E5};
    BinaryTreeNode C3 = {3, &F6, NULL};
    BinaryTreeNode A1 = {1, &B2, &C3};

    preorder(&A1);
    std::cout << std::endl;
    inorder(&A1);
    std::cout << std::endl;
    postorder(&A1);
    std::cout << std::endl;
    return 0;
}
